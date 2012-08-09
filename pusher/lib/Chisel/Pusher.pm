######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::Pusher;

use strict;
use warnings;
use Carp;
use Log::Log4perl;
use Group::Client;
use Chisel::Builder::Engine;
use IPC::Open3 qw/open3/;
use POSIX qw/:sys_wait_h/;
use Hash::Util;
use YAML::XS ();
use File::Find ();
use Sys::Hostname ();

sub new {
    my ( $class, %rest ) = @_;

    my $defaults = {
        pushtar         => '',    # tarball that we should push
        role            => undef, # name of the role that contains all transports we should push to
        roles_throttle  => 60,    # minimum number of seconds between roles queries
        status_throttle => 10,    # minimum number of seconds between writing out status updates
        push_throttle   => 3600,  # minimum number of seconds between pushes of the same directory to one host
        maxflight       => 5,     # maximum number of concurrent pushes
        statusfile      => '',    # file to write status to
        dropbox         => '',    # location of dropbox on the transport
        hosttime        => {},
    };

    my $self = { %$defaults, %rest };

    if( keys %$self > keys %$defaults ) {
        confess "Too many parameters";
    }

    # Engine object
    $self->{engine} = Chisel::Builder::Engine->new;

    # Group object
    $self->{group} = $self->{engine}->roles;


    bless $self, $class;
    Hash::Util::lock_keys(%$self);
    return $self;
}

sub logger {
    Log::Log4perl->get_logger(__PACKAGE__);
}


sub run {
    my ( $self, %args ) = @_;

    $self->logger->info( "Push loop started [group $self->{group}]" );

    my $pushtar = $self->{pushtar};

    my %hostpid;     # $hostpid{ host } = pid of the process pushing to this host
                     #   and keys %hostpid = hosts currently being pushed
    my %hostlast;    # $hostlast{ host } = last pushtar mtime that was pushed to this host
                     #   or undef if there was a failure
                     #   and keys %hostlast = all hosts we have ever tried to push to
    my %pushpid;     # $pushpid{ pid } = 1 if a push from this pid is in flight
                     #   and keys %pushpid = all pids currently pushing
    my $roletime;    # $roletime = last time we finished querying roles
    my $statustime;  # $statustime = last time we wrote status

    while( 1 ) {
        # clean up any kids that have finished
        if( keys %pushpid ) {

            do {
                my $cpid = waitpid( -1, WNOHANG );
                select( undef, undef, undef, 0.1 );

                if( $cpid > 0 ) {
                    my $status = $?;
                    my $dir_pushed = delete $pushpid{ $cpid };

                    $self->logger->debug( "Cleaning up after pid $cpid (status "
                          . ( $status >> 8 ) . ") (" . ( scalar keys %pushpid )
                          . " children still running)" );

                    # get hostname for this push
                    my ( $hostname ) = grep { $hostpid{$_} == $cpid } keys %hostpid;

                    if( $hostname ) {
                        delete $hostpid{$hostname};
                        $self->{hosttime}->{$hostname} = time if exists $self->{hosttime}->{$hostname};

                        if( $status >> 8 == 2 ) {
                            $self->logger->warn( "Transport Locked: $hostname" );
                            
                        } elsif( $status ) {
                            $self->logger->warn( "Failed: $hostname" );
                            $hostlast{$hostname} = undef;
                            
                        } else {
                            $self->logger->info( "DONE: $hostname" );
                            $hostlast{$hostname} = $dir_pushed;
                            
                        }
                    } else {
                        $self->logger->warn( "Could not find hostname to match pid $cpid" );
                    }
                }
            } while( keys %pushpid >= $self->{maxflight} )
        } else {
            sleep 1;
        }

        # update transport list, maybe
        if( !$roletime || ( !$args{once} && time > $roletime + $self->{roles_throttle} ) ) {
            $self->logger->debug( "Refreshing role $self->{role}" );

            eval {
                my %members = map { $_ => 1 } @ { $self->{rocl}->role( $self->{role}, "members" )->{members} };
                foreach my $host ( keys %{$self->{hosttime}} ) {
                    if ( ! exists( $members{$host} ) ) {
                        delete $self->{hosttime}->{$host};
                    }
                }
                %{$self->{hosttime}} =
                    map { $_ => ( $self->{hosttime}->{$_} || 0 ) } # save old value or set to current time
                    ( keys %members );
                1;
            } or do {
                $self->logger->warn( "Groups: $@" );
            };

            $roletime = time;
        }

        # transport we'd like to push to will go in here
        my $current_transport;

        # determine if we have anything to push
        my @pushtar_stat = stat $pushtar;
        if( @pushtar_stat ) {
            # we have a tarball to push. check its mtime
            my $current_mtime = $pushtar_stat[9];

            # now select a transport to push to
            my $now = time;
            ( $current_transport ) =
              sort { $self->{hosttime}->{$a} <=> $self->{hosttime}->{$b} }    # oldest first
              grep { !$args{once} || !$self->{hosttime}->{$_} }     # respect --once
              grep {
                !(     $hostlast{$_}
                    && $self->{hosttime}->{$_}
                    && $hostlast{$_} == $current_mtime
                    && $self->{hosttime}->{$_} + $self->{push_throttle} > $now )
              }                                           # not ones that got pushed $current_mtime too recently
              grep { !exists $hostpid{$_} }               # not ones that are currently receiving pushes
              keys %{$self->{hosttime}};

            if( $current_transport ) {
                # fork and push_single

                # start a metric timer for this host
                $self->metrics->timer_start( { transport => $current_transport }, "t_duration" );

                # calc wait time in the queue
                if( $self->{hosttime}->{$current_transport} ) {
                    my $wait_time = time - $self->{hosttime}->{$current_transport};
                    $self->metrics->set_metric( {}, "t_wait", $wait_time );
                }

                my $pid = fork;

                if( $pid ) {
                    # parent, record dir/pid and continue
                    $hostpid{ $current_transport } = $pid;
                    $pushpid{ $pid } = $current_mtime;
                    $self->logger->debug( "Spawned pid $pid to push to $current_transport ("
                          . ( scalar keys %pushpid ) . " children running)" );
                } elsif( defined $pid ) {
                    # child
                    eval {
                        $0 = "$0 [push_single $current_transport]";
                        $self->push_single( $current_transport ) or die;
                    };

                    if( $@ ) {
                        exit 1;
                    } else {
                        exit 0;
                    }
                }
            }
        }

        # write some status, in case anyone cares
        if(    ( my $statusfile = $self->{statusfile} )
            && ( !$statustime || $args{once} || time > $statustime + $self->{status_throttle} ) )
        {
            my %status;

            foreach my $hostname ( keys %{$self->{hosttime}} ) {
                # hosts in our role -- we might be pushing to hosts that have dropped from it but whatever

                $status{$hostname}{currentdir} =
                $hostpid{$hostname} && $pushpid{ $hostpid{$hostname} };    # dir that we are currently pushing
                $status{$hostname}{lastdir}  = $hostlast{$hostname};
                $status{$hostname}{lasttime} = $self->{hosttime}->{$hostname};
                $status{$hostname}{error}    = exists $hostlast{$hostname} && !defined $hostlast{$hostname};
            }

            eval {
                YAML::XS::DumpFile( "$statusfile.$$", \%status );
                rename "$statusfile.$$" => $statusfile
                  or die "rename: $!";
            } or do {
                $self->logger->warn( "Could not report status: $@" );
                unlink "$statusfile.$$";
            };
        }

        # if we're in --once and did everything, bail
        last if( $args{once} && !$current_transport && !keys %pushpid );
    }
}

# pushes a particular directory to a single transport
# dies on failure, returns some sort of true value on success
sub push_single {
    my ( $self, $transport ) = @_;

    my $target = "checkout-" . Sys::Hostname::hostname() . ".tar";
    my $ssh_opts = qq( -o ConnectTimeout=10 -o BatchMode=yes -i /conf/builder_keys/push-key -o UserKnownHostsFile=/conf/pusher_ssh_known_hosts );
    my $rsync_cmd = qq( rsync -B 512 -z --timeout=3600 -e 'ssh $ssh_opts' $self->{pushtar} \Qchiseldata\@$transport:$self->{dropbox}/$target\E );

    my $start = time;
    $self->logger->debug( "[push_single $transport] started" );

    # rsync to data to the transport
    my $rsync_pid = open3( my $tin, my $tout, undef, $rsync_cmd ) # undef merges stdout + stderr
      or confess "could not spawn $rsync_cmd";

    close $tin;

    while( my $rsp = <$tout> ) {
        chomp $rsp;
        $self->logger->debug( "[push_single $transport] [rsync] $rsp" ); # whatever rsync says is probably at least mildly important
    }

    close $tout;
    waitpid $rsync_pid, 0; # sets $?

    if( $? == 0 ) {
        $self->logger->debug( "[push_single $transport] finished (" . (time - $start) . " seconds)" );
        return 1;
    } else {
        return;
    }
}

1;
