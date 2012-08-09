#!/usr/bin/perl

use strict;
use warnings;

use ChiselTest::Mock::ZooKeeper;
use Log::Log4perl;
use Test::Differences;
use Test::Exception;
use Test::More tests => 12;
use Chisel::Builder::ZooKeeper::Leader;

Log::Log4perl->init( 't/files/l4p.conf' );

# Create ZooKeeper leader using a mock handle
my $zkh1 = ChiselTest::Mock::ZooKeeper->new;
my $zkh2 = ChiselTest::Mock::ZooKeeper->new( share => $zkh1 );
my $zk1  = Chisel::Builder::ZooKeeper::Leader->new( zkh => $zkh1 );
my $zk2  = Chisel::Builder::ZooKeeper::Leader->new( zkh => $zkh2 );

# Nobody is registered
is( $zk1->registered( "foo" ), undef, "registered(foo)" );
is( $zk1->registered( "bar" ), undef, "registered(bar)" );

# zk2 -> register for foo
is( $zk2->register( "foo" ),   "02",  "zk1->register(foo)" );
is( $zk2->registered( "foo" ), "02",  "registered(foo)" );
is( $zk2->registered( "bar" ), undef, "registered(bar)" );

# zk1 -> register for bar
is( $zk1->register( "bar" ),   "01", "zk2->register(bar)" );
is( $zk1->registered( "foo" ), "02", "registered(foo)" );
is( $zk1->registered( "bar" ), "01", "registered(bar)" );

# Try to re-register and cross-register
is( $zk1->register( "bar" ), "01",  "zk1->register(bar)" );
is( $zk1->register( "foo" ), undef, "zk1->register(foo)" );
is( $zk2->register( "bar" ), undef, "zk2->register(bar)" );
is( $zk2->register( "foo" ), "02",  "zk2->register(foo)" );
