#!/usr/bin/perl -w

# checkoutpack-unicode.t -- tests related to handling of objects with unicode data

use warnings;
use strict;
use File::Temp qw/tempdir/;
use Test::More tests => 4;
use Log::Log4perl;
use ChiselTest::Engine;
use Chisel::CheckoutPack;
use Chisel::RawFile;
use Chisel::Transform;

Log::Log4perl->init( 't/files/l4p.conf' );

my $tmp = tempdir( CLEANUP => 1 );
my $tarfile = "$tmp/cp.tar";

my $cp = Chisel::CheckoutPack->new( filename => $tarfile );
my $cpe = $cp->extract;

# read a raw file and a transform with unicode data
my $checkout = ChiselTest::Engine->new->new_checkout( transformdir => "t/files/configs.1/transforms" );
my ( $transform ) = grep { $_->name eq 'func/UNICODE' } $checkout->transforms;
my ( $raw ) = $checkout->raw( 'unicode' );

# Insert into CheckoutPack and re-extract
$cpe->smash( raws => [$raw], host_transforms => {'foo' => [$transform]});
$cp->write_from_fs($cpe->stagedir);
$cpe = $cp->extract;

# Look at retrieved objects
is( $cpe->raw('unicode')->data, $raw->data, "unicode raw file retrieved" );
is(
    Digest::MD5::md5_hex( $cpe->raw('unicode')->data ),
    '8524f9f669e75c180143c17a2def2863',
    "unicode raw file has correct md5sum"
);

is( $cpe->transform( 'func/UNICODE@e2728973f1889e71f7f4e393089fb2ffc8e4f1f7' )->yaml,
    $transform->yaml, "unicode transform retrieved" );
is(
    $cpe->transform( 'func/UNICODE@e2728973f1889e71f7f4e393089fb2ffc8e4f1f7' )->id,
    'func/UNICODE@e2728973f1889e71f7f4e393089fb2ffc8e4f1f7',
    "unicode transform has correct id"
);
