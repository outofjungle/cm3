#!/usr/bin/perl

use strict;
use warnings;

use ChiselTest::Mock::ZooKeeper;
use List::MoreUtils qw/uniq/;
use Log::Log4perl;
use POSIX qw/ceil/;
use Test::Differences;
use Test::Exception;
use Test::More tests => 120;
use Chisel::Builder::ZooKeeper::Leader;

Log::Log4perl->init( 't/files/l4p.conf' );

# Create ZooKeeper leader using a mock handle
my $zkh = ChiselTest::Mock::ZooKeeper->new;
my $zk = Chisel::Builder::ZooKeeper::Leader->new( zkh => $zkh, cluster => [ 'w0', 'w1', 'w2' ], redundancy => 1 );

# Sample nodemap. The values are arbitrary strings just compared for equality or non-equality
my %nodemap = (
    'foo1'  => 'A',
    'foo2'  => 'A',
    'foo3'  => 'A',
    'foo4'  => 'A',
    'bar1'  => 'B',
    'bar2'  => 'B',
    'baz1'  => 'C',
    'baz2'  => 'C',
    'qux1'  => 'D',
    'wild1' => 'A',
    'wild2' => 'B',
    'wild3' => 'C',
);

sub do_fuzzy_test {
    my @workers = @_;

    # The tests here are a little fuzzy to avoid reworking them if
    # the rebalance algorithm changes a bit

    $zk->{cluster} = [@workers];
    ok( $zk->rebalance( \%nodemap ) );

    eq_or_diff( [ sort $zk->get_workers ], \@workers );

    my $redundancy = $zk->{redundancy};
    my $nw         = scalar $zk->get_workers;

    for my $h ( keys %nodemap ) {
        is( scalar( $zk->get_assignments_for_host( $h ) ), $redundancy, "$redundancy worker(s) for host $h" );
    }

    for my $w ( @workers ) {
        my @hosts   = $zk->get_part( $w );
        my @buckets = uniq @nodemap{@hosts};

        ok( @hosts <= ceil( ( scalar keys %nodemap ) * $redundancy / @workers * 1.5 ), "hosts($w) upper bound" )
          or diag( "$w: workers [@workers] redundancy [$redundancy] hosts [@hosts] buckets [@buckets]" );
        ok( @buckets <= ceil( ( scalar uniq values %nodemap ) * $redundancy / @workers * 1.2 ), "buckets($w) upper bound" )
          or diag( "$w: workers [@workers] redundancy [$redundancy] hosts [@hosts] buckets [@buckets]" );
    }
}

# Start the testing
do_fuzzy_test( qw/w0 w1 w2/ );

# Create new bucket from the wild1's
$nodemap{'wild1'} = 'E';
$nodemap{'wild2'} = 'E';
$nodemap{'wild3'} = 'E';
do_fuzzy_test( qw/w0 w1 w2/ );

# Increase redundancy
$zk->{redundancy} = 2;
do_fuzzy_test( qw/w0 w1 w2/ );

# Add a worker
do_fuzzy_test( qw/w0 w1 w2 w3/ );

# Lower redundancy
$zk->{redundancy} = 1;
do_fuzzy_test( qw/w0 w1 w2 w3/ );

# Remove all but one worker
do_fuzzy_test( qw/w0/ );
