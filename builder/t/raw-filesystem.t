#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 9;
use Test::Differences;
use Test::Exception;
use Chisel::Builder::Raw;
use Chisel::Builder::Raw::Filesystem;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

# set up a raw system
# this is also kinda testing Raw.pm's routing mechanism a little bit

my $raw = Chisel::Builder::Raw->new->mount(
    plugin     => Chisel::Builder::Raw::Filesystem->new( rawdir => "t/files/configs.1/raw" ),
    mountpoint => "/",
  )->mount(
    plugin     => Chisel::Builder::Raw::Filesystem->new( rawdir => "t/files/configs.1/modules" ),
    mountpoint => "/modules",
  )->mount(
    plugin     => Chisel::Builder::Raw::Filesystem->new( rawdir => "t/files/configs.1/nonexistentsorry" ),
    mountpoint => "/nonex",
  );

# try to read some files out of it
is( $raw->raw( key => "rawtest" ),                     "line one\nline two\n" );
is( $raw->raw( key => "rawtest" ),                     "line one\nline two\n" ); # same one to make sure it still works
is( $raw->raw( key => "modules/passwd/files/base" ),   "root:*:0:0:System Administrator:/var/root:/bin/sh\n" );

# try some files that should fail
throws_ok { $raw->raw( key => "/modules/passwd/module.conf" ) } qr!\Q[/modules/passwd/module.conf] could not be fetched\E!;
throws_ok { $raw->raw( key => "/rawtest2" ) } qr!\Q[/rawtest2] could not be fetched\E!;
throws_ok { $raw->raw( key => "/./rawtest" ) } qr!\Q[/./rawtest] could not be fetched\E!;
throws_ok { $raw->raw( key => "lolz" ) } qr/\[lolz\] could not be fetched/;
throws_ok { $raw->raw( key => "nonex/what" ) } qr/\[nonex\/what\] could not be fetched/;
throws_ok { $raw->raw( key => "nonex" ) } qr/\[nonex\] could not be fetched/;
