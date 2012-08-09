######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::Workspace;

# ws/
#    nodemap.memdb: see immediately below
#    f/
#      11/
#         2222222222222222222: data with git_sha 112222222222222222222
#    b/
#      11/
#         2222222222222222222: json encoding of bucket with git tree sha 112222222222222222222

# buckets are under their git tree sha ($bucket->tree) as json encoded
# like { "filename" : "blob sha", ... } (the git tree sha is NOT the same
# as the sha of that json!)

# nodemap.memdb key         value
# h + HOSTNAME          => bucket for HOSTNAME

use strict;
use warnings;

use Digest::SHA1 qw/sha1_hex/;
use Fcntl;
use Hash::Util ();
use JSON::XS ();
use Log::Log4perl qw/:easy/;

use Chisel::Bucket;
use Regexp::Chisel qw/:all/;

sub new {
    my ( $class, %rest ) = @_;

    my $defaults = {
        dir       => undef,    # working directory
        mirror    => 0,        # read from nodemap-mirror.memdb instead of nodemap.memdb
                               # useful for low-latency applications like apache
    };

    my $self = { %$defaults, %rest };
    if( keys %$self > keys %$defaults ) {
        die "Too many parameters, expected only " . join ", ", keys %$defaults;
    }

    # dir is required
    if( !$self->{dir} ) {
        LOGCONFESS "no 'dir' provided";
    }

    if( !-d $self->{dir} ) {
        LOGCONFESS "'dir' does not exist: $self->{dir}";
    }

    # memdb_File handle
    $self->{memdb} = undef;

    # Blob directories
    if( !$self->{'mirror'} ) {
        my @dirs = ( "b", "f", map { ( "b/$_", "f/$_" ) } map { lc sprintf( "%02X", $_ ) } ( 0 .. 255 ) );
        foreach my $d ( @dirs ) {
            if( !-d "$self->{dir}/$d" ) {
                mkdir "$self->{dir}/$d" or LOGCONFESS "mkdir $self->{dir}/$d: $!";
            }
        }
    }

    # How many times did we lock the memdb through "lock_and"?
    # On 0 -> 1 we call memdb_lock
    # On 1 -> 0 we call memdb_unlock
    $self->{memdb_lock} = 0;

    bless $self, $class;
    Hash::Util::lock_keys(%$self);
    return $self;
}

sub memdb {
    my ( $self ) = @_;

    if( !$self->{memdb} ) {
        my %memdb;
        my $flags = $self->{'mirror'} ? O_RDONLY : O_RDWR | O_CREAT;
        my $file = $self->{'mirror'} ? "nodemap-mirror.memdb" : "nodemap.memdb";

        if( tie( %memdb, 'memdb_File', "$self->{dir}/$file", $flags, 0644 ) ) {
            $self->{memdb} = \%memdb;
        } else {
            LOGCONFESS "cannot open $self->{dir}/nodemap.memdb ($!)";
        }
    }

    return $self->{memdb};
}

sub lock_and {
    my ( $self, $code ) = @_;

    if(!$self->{memdb_lock}) {
        (tied %{$self->memdb})->lock == 1 or LOGCONFESS "cannot lock nodemap.memdb";
    }

    $self->{memdb_lock}++;

    my $ret = wantarray ? [ eval { $code->(); } ] : eval { $code->(); };
    my $err = $@;

    $self->{memdb_lock}--;

    if(!$self->{memdb_lock}) {
        (tied %{$self->memdb})->unlock;
    }

    if( $err ) {
        LOGCONFESS $err;
    } else {
        return wantarray ? @$ret : $ret;
    }
}

# get current list of hosts from the memdb
sub hosts {
    my ( $self ) = @_;

    # XXX this lock is held for far too long
    return $self->lock_and(
        sub {
            my @hosts;
            foreach my $k (keys %{$self->memdb}) {
                if( $k =~ /^h(.+)/ ) {
                    push @hosts, $1;
                }
            }
            return @hosts;
        }
    );
}

# get bucket id for a single host
# return undef if the host does not exist in nodemap.memdb
sub host_bucketid {
    my ( $self, $host ) = @_;

    my $bucketid = $self->lock_and(
        sub {
            return $self->memdb->{"h$host"};
        }
    );

    return $bucketid;
}

# get entire Bucket object for a single host
# return undef if the host does not exist in nodemap.memdb
sub host_bucket {
    my ( $self, $host ) = @_;

    my $bucketid = $self->host_bucketid( $host );

    if( $bucketid ) {
        return $self->bucket( $bucketid );
    } else {
        return undef;
    }
}

# get blob for a single file for a single host
sub host_file {
    my ( $self, $host, $file ) = @_;

    return $self->lock_and(
        sub {
            if( my $bucketid = $self->memdb->{"h$host"} ) {
                if( my $bucketjson = $self->_bucketjson( $bucketid ) ) {
                    return $bucketjson->{$file};
                }
            }

            return undef;
        }
    );
}

# get Bucket object for a bucket id
# return undef if the bucket id does not exist in nodemap.memdb
sub bucket {
    my ( $self, $bucketid ) = @_;

    if( my $bucketjson = $self->_bucketjson( $bucketid ) ) {
        my $bucketobj = Chisel::Bucket->new;
        foreach my $f ( keys %$bucketjson ) {
            $bucketobj->add( file => $f, blob => $bucketjson->{$f} );
        }

        return $bucketobj;
    } else {
        return undef;
    }
}

# private method: get decoded bucket json for a bucket
# returns undef if the bucket cannot be located
sub _bucketjson {
    my ( $self, $bucketid ) = @_;
    open my $fh, "<", $self->bucketloc($bucketid)
      or return undef;
    return JSON::XS::decode_json( do { local $/; <$fh> } );
}

# get the node -> bucket map, as a hash
sub nodemap {
    my ( $self, %args ) = @_;

    # XXX this lock is held for far too long
    my $nodemap = $self->lock_and(
        sub {
            my %nodemap = map { $_ => $self->memdb->{"h$_"} } $self->hosts;
            return \%nodemap;
        }
    );

    if( !$args{'no_object'} ) {
        # We need to load actual bucket objects
        my %bucket;
        foreach my $h ( keys %$nodemap ) {
            # XXX - Race with gc (bucket could have been collected)

            my $bucketid = $nodemap->{ $h };
            $bucket{$bucketid} ||= $self->bucket( $bucketid );
            $nodemap->{$h} = $bucket{$bucketid};
        }
    }

    return $nodemap;
}

# location of a blob in our workspace
sub blobloc {
    my ( $self, $blob ) = @_;
    my ( $p1, $p2 ) = ( $blob =~ /^([a-z0-9]{2})([a-z0-9]{38})$/ )
      or LOGCONFESS "wtf? bad blob: $blob\n";
    return "$self->{dir}/f/$p1/$p2";
}

# location of a bucket's json encoding in our workspace
sub bucketloc {
    my ( $self, $tree ) = @_;
    my ( $p1, $p2 ) = ( $tree =~ /^([a-z0-9]{2})([a-z0-9]{38})$/ )
      or LOGCONFESS "wtf? bad tree: $tree\n";
    return "$self->{dir}/b/$p1/$p2";
}

# pull a blob from the repository
sub cat_blob {
    my ( $self, $ident ) = @_;
    open my $fh, "<", $self->blobloc($ident)
      or LOGCONFESS "blob not found: $ident";
    my $content = do { local $/; <$fh> };
    return $content;
}

# add a blob to the object database, and returns its id
sub store_blob {
    my ( $self, $contents ) = @_;

    if( $self->{'mirror'} ) {
        LOGCONFESS "cannot run on mirror";
    }

    my $ident = $self->git_sha('blob', $contents);
    my $loc = $self->blobloc($ident);

    if( !-f $loc ) {
        my $loctmp = "$loc.$$";
        sysopen my $fh, $loctmp, O_CREAT | O_EXCL | O_WRONLY, 0644
          or LOGDIE "open $loctmp: $!";
        print $fh $contents;
        close $fh or LOGDIE "close $loctmp: $!";
        rename $loctmp, $loc
          or die "rename $loctmp -> $loc: $!\n";
    }

    return $ident;
}

# write a bucket to the object database, and returns its id
sub store_bucket {
    my ( $self, $bucket ) = @_;

    if( $self->{'mirror'} ) {
        LOGCONFESS "cannot run on mirror";
    }

    my $ident = $bucket->tree;
    my $loc   = $self->bucketloc( $ident );

    if( !-f $loc ) {
        my $m = $bucket->manifest( emit => ['blob'], include_dotfiles => 1 );
        my %mf = map { $_ => $m->{$_}{blob} } keys %$m;
        my $json = JSON::XS::encode_json( \%mf );

        my $loctmp = "$loc.$$";
        sysopen my $fh, $loctmp, O_CREAT | O_EXCL | O_WRONLY, 0644
          or LOGDIE "open $loctmp: $!";
        print $fh $json;
        close $fh or LOGDIE "close $loctmp: $!";
        rename $loctmp, $loc
          or die "rename $loctmp -> $loc: $!\n";

        DEBUG "store_bucket: $ident";
    }

    return $ident;
}

# commit a host -> bucket association
# use "undef" for the bucket to remove the host.
# it might be nice to have a bulk API? should check if that would help performance at all.
sub write_host {
    my ( $self, $host, $bucketid ) = @_;

    if( $self->{'mirror'} ) {
        LOGCONFESS "cannot run on mirror";
    }

    $self->lock_and(
        sub {
            if( defined $bucketid ) {
                TRACE "commit_host: host -> $bucketid";
                $self->memdb->{"h$host"} = "$bucketid";
            } else {
                TRACE "commit_host: host -> NULL";
                delete $self->memdb->{"h$host"};
            }
        }
    );
}

# update nodemap-mirror.memdb
sub commit_mirror {
    my ( $self ) = @_;

    if( $self->{'mirror'} ) {
        LOGCONFESS "cannot run on mirror";
    }

    DEBUG "commit_mirror: replacing nodemap-mirror.memdb";

    my $memdb_mirror_new_name = "$self->{dir}/nodemap-mirror.memdb.$$";
    my %memdb_mirror_new;
    tie( %memdb_mirror_new, 'memdb_File', $memdb_mirror_new_name, O_RDWR | O_CREAT | O_EXCL, 0644 )
      or LOGCONFESS "cannot open $memdb_mirror_new_name ($!)";

    $self->lock_and(
        sub {
            for my $key ( keys %{ $self->memdb } ) {
                $memdb_mirror_new{$key} = $self->memdb->{$key};
            }
        }
    );

    (tied %memdb_mirror_new)->sync;
    untie %memdb_mirror_new;

    my $rc = system("memdb_replace", "$self->{dir}/nodemap-mirror.memdb", $memdb_mirror_new_name);
    if($rc != 0) {
        LOGCONFESS "cannot replace nodemap-mirror.memdb";
    }

    INFO "commit_mirror: done";
    return;
}

# garbage-collect the workspace
# removes all objects not referenced in nodemap.memdb or provided as "keep_files" or "keep_buckets"
# returns list of objects removed if called in array context
# also supports "dryrun" option -- in that case, returns what would have been removed
sub gc {
    my ($self, %args) = @_;

    if( $self->{'mirror'} ) {
        LOGCONFESS "cannot run on mirror";
    }

    # we might return a list of objects removed
    my @removed;

    # list of files, buckets to keep
    my ( %keep_file, %keep_bucket );

    # keep all files referenced by our nodemap
    DEBUG "gc: reading nodemap";
    my $nodemap = $self->nodemap( no_object => 1 );

    DEBUG "gc: scanning buckets in nodemap";
    foreach my $h ( keys %$nodemap ) {
        my $bucket = $nodemap->{$h};

        if( !$keep_bucket{$bucket} ) {
            $keep_bucket{$bucket} = 1;
            $keep_file{$_} = 1 for values %{ $self->_bucketjson( $bucket ) };
        }
    }

    # add user-provided lists
    DEBUG "gc: reading user-provided keep lists";
    if( $args{'keep_files'} ) {
        $keep_file{$_} = 1 for @{$args{'keep_files'}};
    }

    if( $args{'keep_buckets'} ) {
        $keep_bucket{$_} = 1 for @{$args{'keep_buckets'}};
    }

    # remove other files
    DEBUG "gc: removing garbage";
    my @dirs = ( map { ( "b/$_", "f/$_" ) } map { lc sprintf( "%02X", $_ ) } ( 0 .. 255 ) );
    foreach my $hex (map { lc sprintf( "%02X", $_ ) } ( 0 .. 255 )) {
        my $scandir = sub {
            my ($dir, $keep) = @_;
            opendir( my $dh, "$dir/$hex" ) or LOGCONFESS "opendir $dir/$hex: $!";
            while( my $f = readdir( $dh ) ) {
                my $fpath = "$dir/$hex/$f";
                if( $f !~ /^\./ && -f $fpath && !$keep->{"$hex$f"} ) {
                    push @removed, "$hex$f";

                    if( !$args{'dryrun'} ) {
                        unlink $fpath or LOGCONFESS "unlink $fpath: $!";
                    }
                }
            }

            closedir $dh;
        };

        # scan b/$hex/ and f/$hex/
        $scandir->( "$self->{dir}/b", \%keep_bucket );
        $scandir->( "$self->{dir}/f", \%keep_file );
    }

    DEBUG "gc: done";

    if( wantarray ) {
        return @removed;
    } else {
        return;
    }
}

# helper function: computes git blob shas
sub git_sha {
    my ( $self, $type, $data ) = @_;
    return sha1_hex( "$type " . ( length $data ) . "\0" . $data );
}

1;
