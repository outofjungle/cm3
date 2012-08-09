#!/usr/bin/perl

use strict;
use warnings;

use ChiselTest::Mock::ZooKeeper;
use Log::Log4perl;
use Test::Differences;
use Test::Exception;
use Test::More tests => 6;
use Chisel::Builder::ZooKeeper::Leader;

Log::Log4perl->init( 't/files/l4p.conf' );

# Create ZooKeeper leader using a mock handle
my $zkh = ChiselTest::Mock::ZooKeeper->new;
my $zk = Chisel::Builder::ZooKeeper::Leader->new( zkh => $zkh );

is( $zk->config("foo"), undef, "config(foo)" );
is( $zk->config("bar"), undef, "config(bar)" );

$zk->config("bar" => "2");

is( $zk->config("foo"), undef, "config(foo)" );
is( $zk->config("bar"), "2", "config(bar)" );

$zk->config("foo" => "baz");

is( $zk->config("foo"), "baz", "config(foo)" );
is( $zk->config("bar"), "2", "config(bar)" );
