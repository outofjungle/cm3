#!/usr/bin/perl -w

# overmind-build-generate-error.t -- test overmind when confronted with generation errors

use strict;
use warnings;

use ChiselTest::Overmind qw/:all/;
use Test::More tests => 12;

my $overmind = tco_overmind;
my $zkl      = $overmind->engine->new_zookeeper_leader;
$zkl->update_part(
    worker => 'worker0',
    part   => [qw! bin0 foo1 foo2 !],
);

# Handle to CheckoutPack
my $cp = Chisel::CheckoutPack->new( filename => $overmind->engine->config( "var" ) . "/dropbox/checkout-p0.tar" );
my $cpe = $cp->extract;

# First run
$overmind->run_once;
nodelist_is( [qw! bin0 foo1 foo2 !] );
blobsha_is( 'bin0', 'files/fake.png/MAIN', "8c8c0b4336192e56423048c7a7b604e722fe579e" );
blob_is( 'bin0', '.error', undef );

# Remove fake.png -- necessary raw file
my $smash = tco_smash0;
$smash->{raws} = [ grep { $_->name ne 'fake.png' } @{ $smash->{raws} } ];

# Re-write CheckoutPack
sleep 1;
$cpe->smash( %$smash );
$cp->write_from_fs( $cpe->stagedir );

# Second run
$overmind->run_once;
nodelist_is( [qw! bin0 foo1 foo2 !] );
blob_is( 'bin0', 'files/fake.png/MAIN', undef );
blob_is( 'bin0', '.error',          "file does not exist: fake.png\n" );

# Add back fake.png, but remove rawtest
$smash = tco_smash0;
$smash->{raws} = [ grep { $_->name ne 'rawtest' } @{ $smash->{raws} } ];

# Re-write CheckoutPack
sleep 1;
$cpe->smash( %$smash );
$cp->write_from_fs( $cpe->stagedir );

# Third run
$overmind->run_once;
nodelist_is( [qw! bin0 foo1 foo2 !] );
blob_is( 'bin0', 'files/fake.png/MAIN', undef );
blob_is( 'bin0', '.error',          "file does not exist: rawtest\n" );

# Add back fake.png
$smash = tco_smash0;

# Re-write CheckoutPack
sleep 1;
$cpe->smash( %$smash );
$cp->write_from_fs( $cpe->stagedir );

# Fourth run -- back to normal
$overmind->run_once;
nodelist_is( [qw! bin0 foo1 foo2 !] );
blobsha_is( 'bin0', 'files/fake.png/MAIN', "8c8c0b4336192e56423048c7a7b604e722fe579e" );
blob_is( 'bin0', '.error', undef );
