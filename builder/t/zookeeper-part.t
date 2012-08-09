#!/usr/bin/perl

use strict;
use warnings;

use ChiselTest::Mock::ZooKeeper;
use Log::Log4perl;
use Test::Differences;
use Test::Exception;
use Test::More tests => 15;
use Chisel::Builder::ZooKeeper::Leader;
use Chisel::Builder::ZooKeeper::Worker;

Log::Log4perl->init( 't/files/l4p.conf' );

# Create ZooKeeper leader using a mock handle
my $zkh = ChiselTest::Mock::ZooKeeper->new;
my $zkl = Chisel::Builder::ZooKeeper::Leader->new( zkh => $zkh, cluster => [ 'w0', 'w1', 'w2' ] );
my $zkw1 = Chisel::Builder::ZooKeeper::Worker->new( zkh => $zkh, worker => 'w1' );

# Assign some hosts to w0 and w1
$zkl->update_part( worker => 'w0', part => [qw/bar baz foo/] );
$zkl->update_part( worker => 'w1', part => [qw/bar baz qux/] );

# Get these assignments using get_part
eq_or_diff( [ sort $zkl->get_workers ], [ 'w0', 'w1' ] );
eq_or_diff( [ sort $zkw1->get_part ], [qw/bar baz qux/] );
eq_or_diff( [ sort $zkw1->get_part( 'w0' ) ], [qw/bar baz foo/] );
eq_or_diff( [ sort $zkw1->get_part( 'w1' ) ], [qw/bar baz qux/] );
eq_or_diff( [ sort $zkw1->get_part( 'w2' ) ], [] );

# Get these assignments using get_assignments_for_host
eq_or_diff( [ sort $zkl->get_assignments_for_host( 'bar' ) ], [qw/w0 w1/] );
eq_or_diff( [ sort $zkl->get_assignments_for_host( 'baz' ) ], [qw/w0 w1/] );
eq_or_diff( [ sort $zkl->get_assignments_for_host( 'foo' ) ], [qw/w0/] );
eq_or_diff( [ sort $zkl->get_assignments_for_host( 'qux' ) ], [qw/w1/] );

# Swap assignments for w0 and w1
$zkl->update_part( worker => 'w0', part => [qw/bar baz qux/] );
$zkl->update_part( worker => 'w1', part => [qw/bar baz foo/] );

# Check the results
eq_or_diff( [ sort $zkl->get_part( 'w0' ) ], [qw/bar baz qux/] );
eq_or_diff( [ sort $zkl->get_part( 'w1' ) ], [qw/bar baz foo/] );

# Nuke w0
$zkl->update_part( worker => 'w0', part => [] );

# Check the results
eq_or_diff( [ sort $zkl->get_workers ], ['w1'] );
eq_or_diff( [ sort $zkl->get_part( 'w1' ) ], [qw/bar baz foo/] );

# Try some bad arguments
throws_ok { $zkl->update_part } qr/Missing 'worker'/;
throws_ok { $zkl->update_part( worker => 'w0', ) } qr/Missing 'part'/;
