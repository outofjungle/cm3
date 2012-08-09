#!/usr/bin/perl -w

# overmind-build-update-raw.t -- test overmind when raw files change

use strict;
use warnings;

use ChiselTest::Overmind qw/:all/;
use Test::More tests => 9;

my $overmind = tco_overmind;
my $zkl      = $overmind->engine->new_zookeeper_leader;
$zkl->update_part(
    worker => 'worker0',
    part   => [ 'bad0', 'mb0' ],
);

# Handle to CheckoutPack
my $cp = Chisel::CheckoutPack->new( filename => $overmind->engine->config( "var" ) . "/dropbox/checkout-p0.tar" );
my $cpe = $cp->extract;

# First run
$overmind->run_once;
blob_is( 'bad0', 'files/motd/MAIN',   undef );
blob_is( 'bad0', '.error',            "file does not exist: nonexistent\n" );
blob_is( 'mb0', 'files/passwd/linux', "root:x:0:0:System Administrator:/var/root:/bin/sh\n" );

# Add "nonexistent" and modify "passwd.bundle/base"
my $smash = tco_smash0;
$smash->{raws} = [ grep { $_->name ne 'passwd.bundle/base' } @{ $smash->{raws} } ];
push @{ $smash->{raws} }, Chisel::RawFile->new( name => "nonexistent", data => "no longer nonexistent\n" ),
  Chisel::RawFile->new( name => "passwd.bundle/base", data => "root:*:0:0:Charlie Root:/var/root:/bin/sh\n" );

# Re-write CheckoutPack
sleep 1;
$cpe->smash( %$smash );
$cp->write_from_fs( $cpe->stagedir );

# Second run
$overmind->run_once;
blob_is( 'bad0', 'files/motd/MAIN',   "hello world\nqux motd\nno longer nonexistent\n" );
blob_is( 'bad0', '.error',            undef );
blob_is( 'mb0', 'files/passwd/linux', "root:x:0:0:Charlie Root:/var/root:/bin/sh\n" );

# Delete "nonexistent" again
$smash->{raws} = [ grep { $_->name ne 'nonexistent' } @{ $smash->{raws} } ];

# Re-write CheckoutPack
sleep 1;
$cpe->smash( %$smash );
$cp->write_from_fs( $cpe->stagedir );

# Third run
$overmind->run_once;
blob_is( 'bad0', 'files/motd/MAIN',   undef );
blob_is( 'bad0', '.error',            "file does not exist: nonexistent\n" );
blob_is( 'mb0', 'files/passwd/linux', "root:x:0:0:Charlie Root:/var/root:/bin/sh\n" );
