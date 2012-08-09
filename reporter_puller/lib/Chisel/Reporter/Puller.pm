######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::Reporter::Puller;

use strict;
use warnings;

use Carp;
use Hash::Util;
use JSON::XS;
use LWP::UserAgent;
use Log::Log4perl;
use POSIX qw/:sys_wait_h/;
use Socket;
use Regexp::Chisel qw/$RE_CHISEL_hostname/;


my $SQL = <<EOSQL;
REPLACE INTO `logs` (`time`, `node`, `script`, `code`, `runtime`, `version`, `fail`) VALUES (FROM_UNIXTIME(?), ?, ?, ?, ?, ?, ?)
EOSQL

sub new {
    my ( $class, %rest ) = @_;

    my %defaults = (
        dbh          => undef,    # database handle (for cloning)
        max_children => 5,        # number of concurrent requests to clusters
        min_wait     => 300,      # number of seconds that must pass before a cluster is re-queried
        rc           => undef,    # roles client handle
        timeout      => 5,        # seconds to wait when trying to pull from clusters
        ua           => undef,    # LWP::UserAgent handle
        ua_create_t  => 0,        # 
        use_ssl      => 0,        # use https on 4443 instead of http on 4080
        clusters     => [],       # clusters to pull from
        node_ids     => {},       # node_name => node_id
        script_ids   => {},       # script_name => script_id
        
    );

    my $self = { %defaults, %rest };

    if( keys %$self > keys %defaults ) {
        confess "Too many parameters";
    }

    # This is ugly, maybe convert the :easy side
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);


    # database handle
    unless( $self->{dbh} ) {
        $logger->logdie( "Database handle required" );
    }

    # sanity check clusters
    unless( scalar @{ $self->{clusters} } > 0 ) {
        $logger->logdie( "No clusters provided" );
    }

    bless $self, $class;
    Hash::Util::lock_keys( %$self );
    return $self;
}

# LWP::UserAgent
sub ua {
    my ($self) = @_;
    my $now = time;
    if( !$self->{ua} || ( $now - $self->{ua_create_t} ) > 86400 ) {
        $self->logger->info( "Refreshing UA handle." );
        $self->{ua_create_t} = $now;
        $self->{ua}          = LWP::UserAgent->new();
        $self->{ua}->timeout( $self->{timeout} );

        
    }
    return $self->{ua};
}

sub dbh {
    my $self = shift;
    return $self->{dbh};
}

sub logger {
    Log::Log4perl->get_logger( __PACKAGE__ );
}

# This runs the main 'Server' loop, which spawns a child for each
# cluster it wants to fetch reporting data from. These children poll
# the cluster communicate back their success status to the parent
# process via a unix domain socket. Specifically, they indicate their
# success or failure, the cluster they contacted and the oldest
# timestamp of the reports that they received. The socket connections
# are handled synchronously, and socket failure causes the pull to
# that cluster to fail.
sub run {
    my ( $self, %args ) = @_;

    # XXX: maybe initialize this from the db to prevent first queries
    # from taking a long time.
    # initialize our cluster => 'most recent record' map
    my %last = map { $_ => 0 } @{ $self->{clusters} };

    # initialize our cluster => 'local time of last attempted check' map
    my %last_check = map { $_ => 0 } @{ $self->{clusters} };

    # prepare query string
    my $url_pattern;
    if( $self->{use_ssl} ) {
        $url_pattern = "https://%s:443/pull?last=%d";
        $self->logger->info( "Using SSL" );
    } else {
        $url_pattern = "http://%s:80/pull?last=%d";
        $self->logger->info( "Not using SSL" );
    }

    # open Server socket
    my ( $sock, $uaddr, $proto );
    eval {
        $sock  = '/tmp/reporter_puller';
        $uaddr = sockaddr_un( $sock );
        $proto = getprotobyname( 'tcp' );
        socket( Server, PF_UNIX, SOCK_STREAM, 0 )
          or die "socket: $!";
        unlink( $sock );
        bind( Server, $uaddr )
          or die "bind: $!";
        listen( Server, SOMAXCONN )
          or die "listen: $!";
    } or do {
        $self->logger->error( "Couldn't setup socket: $@" );
        sleep 1;
        exit 1;
    };

    $self->logger->info( "Running" );
    my %kids;    # pid => time started
    while( 1 ) {
        sleep 1;
        my $now = time;
        # choose the least-recently-sync'd cluster, breaking ties by name
        my @sorted_list = sort { $last{$a} <=> $last{$b} or $a cmp $b } @{ $self->{clusters} };
        $self->logger->debug( "@sorted_list" );
        foreach my $cluster ( @sorted_list ) {
            sleep 1;
            last if scalar keys %kids >= $self->{max_children};
            next if grep { $cluster eq $_->[1] } values %kids;
            next unless( $now - $last_check{$cluster} > $self->{min_wait} );

            # this will make sure the LWP::UserAgent handle is
            # up-to-date (ie. it's YCA certs are fresh) before we fork
            # and our children use it.
            $self->ua;

            my $pid = fork;
            if( !defined( $pid ) ) {
                $self->logger->error( "Fork failed: $!" );
                next;
            } elsif( $pid > 0 ) {
                $kids{$pid} = [ scalar time, $cluster ];
                $last_check{$cluster} = $now;
                $self->logger->info( "Child $pid started $cluster" );
            } else {
                $self->logger->debug( "Child start: $cluster" );

                # reset our signal handlers
                $SIG{INT} = $SIG{HUP} = $SIG{TERM} = 'DEFAULT';

                # connect to parent socket
                eval {
                    socket( Parent, PF_UNIX, SOCK_STREAM, 0 ) || die "socket: $!";
                    connect( Parent, $uaddr ) || die "connect: $!";
                } or do {
                    $self->logger->error( "Couldn't connect to parent: $@" );
                    exit 1;
                };
                my $message = "FAILURE $cluster 0 0";

                # get reporting data
                my $res = $self->ua->get( sprintf( $url_pattern, $cluster, $last{$cluster} ) );
                if( $res->is_success ) {
                    my $json = $res->decoded_content();
                    my $data = {};

                    eval { $data = decode_json $json; };
                    if ($@) {
                        $self->logger->error( "Bad JSON from $cluster, skipping." );
                    } else {
                        my $dbh_clone = $self->dbh->clone( { InactiveDestroy => 1 } );
                        my $sth       = $dbh_clone->prepare( $SQL );
                        my $latest    = $self->insert_data( $dbh_clone, $data );

                        $self->logger->debug( "Pulled from $cluster" );
                        $message = sprintf("SUCCESS %s %d %d", $cluster, $latest, scalar keys %$data);
                    }
                } else {
                    $self->logger->warn( sprintf( "Couldn't pull from %s: %s", $cluster, $res->status_line ) );
                    $message = sprintf("FAILURE %s %d %d", $cluster, 0, 0);
                }
                print Parent $message;
                close Parent;
                $self->logger->debug( "Child EOL: $cluster" );
                exit 0;
            } # child EOL
        }

        # Handle incoming communications.
        my $paddr;
        my ( $stat, $trans, $translast, $datasize ) = ( "", "", 0, 0 );

        eval {
            local $SIG{ALRM} = sub { die "timeout waiting for child message" };
            alarm 1;
            $paddr = accept( Client, Server );
            alarm 0;
        } or do {
            $self->logger->warn( "accept: $@" )
              unless $@ =~ m/^timeout/;
        };
        if( $paddr ) {
            my $clientmsg = do { local $/; <Client> };
            if (!$clientmsg) {
                $self->logger->error( "No message received from child." );
            } else {
                ( $stat, $trans, $translast, $datasize ) = split /\s+/, $clientmsg;
                unless(( $stat eq 'SUCCESS' || $stat eq 'FAILURE' )
                       && ( $trans =~ m/^$RE_CHISEL_hostname\z/ ) )
                {
                    $self->logger->error( "Bad message from child: $clientmsg" );
                }
                $self->logger->debug( "Got: $clientmsg" );
                if( $stat eq 'SUCCESS' and $translast > $last{$trans} ) {
                    $last{$trans} = $translast;
                }
            }
        } else {
            $self->logger->error( "accept: $!" )
              unless $! =~ m/^Interrupted system call/;
        }
        close Client;

        # clean up already-dead kids
        foreach my $p ( keys %kids ) {
            my $rp = waitpid( $p, WNOHANG );
            select( undef, undef, undef, 0.1 );
            if( $rp == $p ) {
                $self->logger->info(
                    sprintf(
                        "Child %d finished %s in %d seconds.",
                        $p,
                        ( $kids{$p} )->[1],
                        time - ( $kids{$p} )->[0]
                    ) );

                delete $kids{$p};
            }
        }
    } # while 1
}

# insert $data into the database, returning the largest timestamp
# in the inserted data or undef on failure.
sub insert_data {
    my ( $self, $dbh, $data ) = @_;
    my $last = 0;
    my $sth  = $dbh->prepare( $SQL );
    foreach my $h ( keys %$data ) {    # $h = 'a.f.c'
        my %host_reports = %{ $data->{$h} };            # {'localtime' => [123,'0','1','123'], ... } ... }
        my $host_id = $self->get_node_id( $h, $dbh );

        my $oldies = 0;                                 # number of script-reports that are older than what is in the db
        my @script_names = grep { $_ ne 'meta' } keys %{ $data->{$h} };
        foreach my $s ( @script_names ) {               # $s = 'localtime'
            my $script_id = $self->get_script_id( $s, $dbh );
            my @report = map { $_ ? int( $_ ) : 0 } @{ $data->{$h}{$s} };    # [123,0,1,123]
            my $is_fail = $report[1] != 0 ? 1 : 0;

            # don't replace new report with old
            my $is_old = $self->is_old(
                host_id   => $host_id,
                script_id => $script_id,
                new_time  => $report[0],
                dbh       => $dbh
            );
            if( $is_old ) { $oldies++; next; } # TODO: Once 2.x is fully deployed, we can remove this check

            # keep $last up to date
            if ($report[0] > $last) {
              $last = $report[0];
            }

            # do the thing
            $sth->execute(
                $report[0],    # time
                $host_id,      # host id
                $script_id,    # script id
                $report[1],    # code
                $report[2],    # runtime
                $report[3],    # version
                $is_fail,      # fail
            );
        }

        # if a single script report is new, the meta-data is new
        $self->update_node_metadata( $host_id, $data->{$h}{meta}, $dbh ) unless( $oldies == scalar @script_names );
    }

    return $last;
}

# return true if the supplied 'new_time' is older than or the same as
# the current value in the database, false otherwise.
sub is_old {
    my ( $self, %args ) = @_;
    my $dbh = $args{dbh};
    my $res = $dbh->selectrow_arrayref( "SELECT MAX(UNIX_TIMESTAMP(`time`)) FROM `logs` WHERE `node` = ? AND `script` = ?",
        undef, $args{host_id}, $args{script_id} );
    return $res->[0] && $res->[0] >= $args{new_time};
}

# return node id for given node name. If the node doesn't exist,
# create it.
sub get_node_id {
    my ( $self, $name, $dbh ) = @_;

    # We're not doing this in one query to avoid incrementing the auto_increment counter in the case
    # that the node exists but is not in $self->{node_ids}
    unless( exists $self->{node_ids}{$name} ) {
        my $res = $dbh->selectrow_arrayref( "SELECT `id` FROM `nodes` WHERE `node` = ?", undef, $name );
        if ( !$res || !@$res ) {
            $self->logger->trace( "Inserting new node $name" );
            $dbh->do( "INSERT INTO nodes (`node`, `created`) VALUES (?, UTC_TIMESTAMP())", undef, $name );
            $res = $dbh->selectrow_arrayref( "SELECT `id` FROM `nodes` WHERE `node` = ?", undef, $name );
            $self->logcroak( "Insert failed" ) unless scalar @$res > 0;
        }
        $self->{node_ids}{$name} = int( $res->[0] );
    }

    $self->logger->trace( "Found id " . $self->{node_ids}{$name} . " for $name" );
    return $self->{node_ids}{$name};
}

sub update_node_metadata {
    my ( $self, $id, $meta, $dbh ) = @_;

    # update metadata if supplied, otherwise delete metadata
    if( $meta->{client} and $meta->{client_sync} ) {
        $dbh->do( 'UPDATE `nodes` SET `client` = ?, `client_sync` = ? WHERE `id` = ?',
            undef, $meta->{client}, $meta->{client_sync}, $id, );
    } else {
        $dbh->do( 'UPDATE `nodes` SET `client` = NULL, `client_sync` = NULL WHERE `id` = ?', undef, $id );
    }
}

# returns the script id by name, creating it if necessary.
sub get_script_id {
    my ( $self, $name, $dbh ) = @_;
    unless( exists $self->{script_ids}{$name} ) {
        $dbh->do( "INSERT IGNORE INTO `scripts` (`script`) VALUES (?)", undef, $name );
        my $res = $dbh->selectrow_arrayref( "SELECT `id` FROM `scripts` WHERE `script` = ?", undef, $name );
        croak "Insert failed" unless scalar @$res > 0;
        $self->{script_ids}{$name} = int( $res->[0] );
    }

    return $self->{script_ids}{$name};
}

1;
