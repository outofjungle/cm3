#!/usr/bin/perl -w

# overmind-build-update-transforms.t -- test overmind when transforms change

use strict;
use warnings;

use ChiselTest::Overmind qw/:all/;
use Test::More tests => 11;

my $overmind = tco_overmind;
my $zkl = $overmind->engine->new_zookeeper_leader;
$zkl->update_part(
    worker => 'worker0',
    part   => [ 'bar1', 'barqux1', 'foo1' ],
);

# Handle to CheckoutPack
my $cp = Chisel::CheckoutPack->new( filename => $overmind->engine->config( "var" ) . "/dropbox/checkout-p0.tar" );
my $cpe = $cp->extract;

# First run
$overmind->run_once;
nodelist_is( [ 'bar1', 'barqux1', 'foo1' ] );

# Check motds
blob_is( 'foo1', 'files/motd/MAIN',    "hello world\nHello FOO\n" );
blob_is( 'bar1', 'files/motd/MAIN',    "hello world\nHello BAR\nI am bar1\n" );
blob_is( 'barqux1', 'files/motd/MAIN', "hello world\nHello QUX\n" );

# Update some transforms
my $smash = tco_smash0;

# foo1 - Drop by setting transforms to empty list
$smash->{'host_transforms'}{'foo1'} = [];

# bar1 - Update DEFAULT
$smash->{'host_transforms'}{'bar1'} = [ grep { $_->name ne 'DEFAULT' } @{$smash->{'host_transforms'}{'bar1'}} ];
push @{ $smash->{'host_transforms'}{'bar1'} },
  Chisel::Transform->new( name => 'DEFAULT', yaml => "motd: [ append hello world 2 ]\n" );

# Re-write CheckoutPack
sleep 1;
$cpe->smash( %$smash );
$cp->write_from_fs($cpe->stagedir);

# Second run
$overmind->run_once;
nodelist_is( ['bar1', 'barqux1'] );

# Check motds
blob_is( 'bar1', 'files/motd/MAIN',    "hello world 2\nHello BAR\nI am bar1\n" );
blob_is( 'barqux1', 'files/motd/MAIN', "hello world\nHello QUX\n" );

# foo1, barqux1 - Use new DEFAULT
$smash->{'host_transforms'}{'foo1'} = [
    map { $cpe->transform( $_ ) } 'DEFAULT@0dd44340f23ea5e89a9289758d6105590ff04a0e',
    'DEFAULT_TAIL@1d8ff62ef10931b76611097844a52f9d0ea936b1',
    'func/FOO@cff4723c1e4545a2cec9220c64e30a639ccc6dba',
];
$smash->{'host_transforms'}{'barqux1'} = [
    map { $cpe->transform( $_ ) } 'DEFAULT@0dd44340f23ea5e89a9289758d6105590ff04a0e',
    'DEFAULT_TAIL@1d8ff62ef10931b76611097844a52f9d0ea936b1',
    'func/BAR@4f097857906bbe2c2b8a9f5bc19f01506b1ac906',
    'func/QUX@03e9a760575a2eaaba907d3b4321871b1190a7d2',
];

# bar1 - Back to original transform set
$smash->{'host_transforms'}{'bar1'} = tco_smash0()->{'host_transforms'}{'bar1'};

# Re-write CheckoutPack
sleep 1;
$cpe->smash( %$smash );
$cp->write_from_fs($cpe->stagedir);

# Third run
$overmind->run_once;
nodelist_is( ['bar1', 'barqux1', 'foo1'] );

# Check motds
blob_is( 'foo1', 'files/motd/MAIN',    "hello world 2\nHello FOO\n" );
blob_is( 'bar1', 'files/motd/MAIN',    "hello world\nHello BAR\nI am bar1\n" );
blob_is( 'barqux1', 'files/motd/MAIN', "hello world 2\nHello QUX\n" );
