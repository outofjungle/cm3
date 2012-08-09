#!/usr/bin/perl -w

# overmind-build-update-hosts.t -- test overmind when host list changes

use strict;
use warnings;

use ChiselTest::Overmind qw/:all/;
use Test::More tests => 8;

my $overmind = tco_overmind;
my $zkl = $overmind->engine->new_zookeeper_leader;

# First host list
$zkl->update_part(
    worker => 'worker0',
    part   => [qw! bar1 foo1 foo2 !],
);

# First run
$overmind->run_once;
nodelist_is( [qw! bar1 foo1 foo2 !] );
blob_is( 'bar1', 'NODELIST', "bar1\n" );
blob_is( 'foo1', 'NODELIST', "foo1\nfoo2\n" );
blob_is( 'foo2', 'NODELIST', "foo1\nfoo2\n" );

# Second host list
$zkl->update_part(
    worker => 'worker0',
    part   => [qw! bar1 foo1 fooqux1 !],
);

# Second run
$overmind->run_once;
nodelist_is( [qw! bar1 foo1 fooqux1 !] );
blob_is( 'bar1', 'NODELIST',    "bar1\n" );
blob_is( 'foo1', 'NODELIST',    "foo1\nfoo2\n" );
blob_is( 'fooqux1', 'NODELIST', "fooqux1\n" );
