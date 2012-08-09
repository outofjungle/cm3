#!/usr/bin/perl

use strict;
use warnings;

use ChiselTest::Mock::ZooKeeper;
use Log::Log4perl;
use Test::Differences;
use Test::Exception;
use Test::More tests => 19;
use Chisel::Builder::ZooKeeper::Worker;

Log::Log4perl->init( 't/files/l4p.conf' );

# Create ZooKeeper worker using a mock handle
my $zkh  = ChiselTest::Mock::ZooKeeper->new;
my $zkw1 = Chisel::Builder::ZooKeeper::Worker->new( zkh => $zkh, worker => 'w1' );
my $zkw2 = Chisel::Builder::ZooKeeper::Worker->new( zkh => $zkh, worker => 'w2' );

# Create container nodes in /h for various hosts
$zkh->create( '/h',     '' );
$zkh->create( '/h/foo', '' );
$zkh->create( '/h/bar', '' );
$zkh->create( '/h/baz', '' );

# Basics
ok( $zkw1->can_advertise, 'can_advertise' );
is( $zkw1->name, 'w1', 'name' );

# Set up advertisements
ok( $zkw1->advertise( hosts => [ 'foo', 'bar' ] ), 'zkw1->advertise(foo, bar)' );
ok( $zkw2->advertise( hosts => [ 'bar', 'baz' ] ), 'zkw2->advertise(bar, baz)' );

# Check advertisements - all workers
eq_or_diff( [ sort $zkw1->get_workers_for_host( 'foo' ) ], ['w1'] );
eq_or_diff( [ sort $zkw1->get_workers_for_host( 'bar' ) ], [ 'w1', 'w2' ] );
eq_or_diff( [ sort $zkw1->get_workers_for_host( 'baz' ) ], ['w2'] );

# Check advertisements - primary worker
is( $zkw1->get_worker_for_host( 'foo' ), 'w1' );
is( $zkw1->get_worker_for_host( 'bar' ), 'w2' );
is( $zkw1->get_worker_for_host( 'baz' ), 'w2' );

# Adjust advertisements. Also, this time use a callback.
my $testvar;
ok( $zkw1->advertise( hosts => ['baz'], callback => sub { $testvar = 1 } ), 'zkw1->advertise(baz)' );
ok( $zkw2->advertise( hosts => ['bar'] ), 'zkw2->advertise(bar)' );

# Check callback $testvar
ok( $testvar, 'callback set $testvar' );

# Check advertisements - all workers
eq_or_diff( [ sort $zkw1->get_workers_for_host( 'foo' ) ], [] );
eq_or_diff( [ sort $zkw1->get_workers_for_host( 'bar' ) ], ['w2'] );
eq_or_diff( [ sort $zkw1->get_workers_for_host( 'baz' ) ], ['w1'] );

# Check advertisements - primary worker
is( $zkw1->get_worker_for_host( 'foo' ), undef );
is( $zkw1->get_worker_for_host( 'bar' ), 'w2' );
is( $zkw1->get_worker_for_host( 'baz' ), 'w1' );
