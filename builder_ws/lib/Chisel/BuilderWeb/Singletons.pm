######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::BuilderWeb::Singletons;

use strict;

use Log::Log4perl qw/:easy/;
use Chisel::Builder::Engine;
use Cache::Memcached;

my $_engine;
my $_zk;
my $_memcache;
my $_ws;

# module_conf we're going to pass to all new Transform objects
my $_moduleconf;

sub engine {
    $_engine ||= Chisel::Builder::Engine->new( 'log4perl_level' => 'WARN' );
    $_engine->setup( 'root_ok' => 1 );
    return $_engine;
}

# execute some code with a zookeeper handle available
# takes care of automatically reconnecting when needed
# usage: with_zk( sub { my $zk = shift; ... } );
sub with_zk {
    my ( $self, $coderef ) = @_;

    my $engine = engine();

    # Connect to ZooKeeper if handle does not exist yet
    if( !defined $_zk ) {
        my $ZKTRIES = 2;
        for( 1 .. $ZKTRIES ) {
            eval { $_zk ||= $engine->new_zookeeper_worker; };

            if( $@ ) {
                undef $_zk;
            } else {
                last;
            }
        }
    }

    if( defined $_zk ) {
        my $ret
            = wantarray
            ? [ eval { $coderef->($_zk); } ]
            : scalar eval { $coderef->($_zk); };

        if( $@ ) {
            # Some kind of error.
            # In case it was from the ZK handle, undef the handle so it
            # will be automatically reconnected on the next call.
            undef $_zk;

            # Re-throw
            die $@;
        } else {
            return wantarray ? @$ret : $ret;
        }
    } else {
        die "ZooKeeper failed to connect!";
    }
}

sub memcache {
    $_memcache ||= Cache::Memcached->new(
        {
            'servers'            => ["127.0.0.1:11211"],
            'debug'              => 0,
            'compress_threshold' => 10_000,
        }
    );
    return $_memcache;
}

sub ws {
    $_ws = engine()->new_workspace( mirror => 1 );
    return $_ws;
}

sub undef_zk {
    undef $_zk;
}

sub module_conf {
    my $checkout = engine()->new_checkout;
    my %module_conf = map { $_ => $checkout->module( name => $_ ) } $checkout->modules;
    $_moduleconf = \%module_conf;
}

# these are safe to load in the parent apache process, so, do it.
# everything else will be loaded once per child.
BEGIN {
    module_conf();
    engine();
}

1;
