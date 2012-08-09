#!/usr/bin/perl

use strict;
use warnings;

use ChiselTest::Mock::ZooKeeper;
use Log::Log4perl;
use Test::Differences;
use Test::Exception;
use Test::More tests => 8;
use Chisel::Builder::ZooKeeper::Worker;

Log::Log4perl->init( 't/files/l4p.conf' );

# Create ZooKeeper worker using a mock handle
my $zkh = ChiselTest::Mock::ZooKeeper->new;
my $zk = Chisel::Builder::ZooKeeper::Worker->new( worker => 'w0', zkh => $zkh );

# Test ->report call
is( $zk->report( "foo" ), undef, "report(foo)" );

ok( $zk->report( "foo", { a => 2 } ), "report(foo, {a => 2})" );
eq_or_diff( $zk->report( "foo" ), { a => 2 }, "report(foo)" );

ok( $zk->report( "foo", { b => 3 } ), "report(foo, {b => 3})" );
eq_or_diff( $zk->report( "foo" ), { b => 3 }, "report(foo)" );

ok( $zk->report( "bar", { c => 4 } ), "report(bar, {c => 4})" );
eq_or_diff( $zk->report( "bar" ), { c => 4 }, "report(bar)" );

eq_or_diff( $zk->reports, { 'foo' => { b => 3 }, 'bar' => { c => 4 }, }, "reports" );
