#!/usr/bin/perl

# raw.t -- tests of the Raw.pm dispatcher, and also tests of Raw/Hash.pm (it doesn't have a dedicated test file)

use warnings;
use strict;
use Test::More tests => 33;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN {
    use_ok( "Chisel::Builder::Raw" );
    use_ok( "Chisel::Builder::Raw::Hash" );
}

# somewhat contrived tests of the mountpoint dispatcher
do {
    my $raw = Chisel::Builder::Raw->new( now => 0 )->mount(
        plugin     => Chisel::Builder::Raw::Hash->new( hash => { '/foo' => 'bar', 'a/bc' => '123', 'foo/x' => '456' } ),
        mountpoint => "/",
      )->mount(
        plugin     => Chisel::Builder::Raw::Hash->new( hash => { '/foo' => 'foobar', 'a/bc' => 'foo123' } ),
        mountpoint => "/foo",
      )->mount(
        plugin     => Chisel::Builder::Raw::Hash->new( hash => { '/foo' => '2bar', 'a/bc' => '2123' } ),
        mountpoint => "/level2",
      );
    
    # try a few files that should work
    is( $raw->raw( key => 'foo' ),          'bar',    'read raw file "foo" (even though it conflicts with a mountpoint)' );
    is( $raw->raw( key => 'a/bc' ),         '123',    'read raw file "a/bc"' );
    is( $raw->raw( key => 'foo/foo' ),      'foobar', 'read raw file "foo/foo"' );
    is( $raw->raw( key => 'foo/a/bc' ),     'foo123', 'read raw file "foo/a/bc"' );
    is( $raw->raw( key => 'level2/foo' ),   '2bar',   'read raw file "level2/foo"' );
    is( $raw->raw( key => 'level2/a/bc' ),  '2123',   'read raw file "level2/a/bc"' );

    # try one of them as an object
    eq_or_diff( $raw->readraw( 'level2/a/bc' ), Chisel::RawFile->new( name => 'level2/a/bc', data => '2123' ) );

    # try some errors
    throws_ok { $raw->raw( key => 'nonexistent' ) } qr/\[nonexistent\] could not be fetched/, "error on nonexistent raw file 'nonexistent'";
    throws_ok { $raw->raw( key => 'foo/x' ) }       qr/\[foo\/x\] could not be fetched/,      "error on nonexistent raw file 'foo/x' is handled by 'foo' plugin";
    throws_ok { $raw->raw( key => 'level2' ) }      qr/\[level2\] could not be fetched/,      "error on nonexistent raw file 'level2'";

    # try some invalid filenames
    throws_ok { $raw->raw( key => '/foo' ) } qr(\QRaw file [/foo] could not be fetched!);
    like( $raw->{last_nonfatal_error}, qr/Invalid raw file name/ );

    throws_ok { $raw->raw( key => '/a/bc' ) } qr(\QRaw file [/a/bc] could not be fetched!);
    like( $raw->{last_nonfatal_error}, qr/Invalid raw file name/ );

    throws_ok { $raw->raw( key => '/foo/a/bc' ) } qr(\QRaw file [/foo/a/bc] could not be fetched!);
    like( $raw->{last_nonfatal_error}, qr/Invalid raw file name/ );

    throws_ok { $raw->raw( key => '/level2/a/bc' ) } qr(\QRaw file [/level2/a/bc] could not be fetched!);
    like( $raw->{last_nonfatal_error}, qr/Invalid raw file name/ );

    throws_ok { $raw->raw( key => 'foo/' ) } qr(\QRaw file [foo/] could not be fetched!);
    like( $raw->{last_nonfatal_error}, qr/Invalid raw file name/ );

    throws_ok { $raw->raw( key => 'foo//x' ) } qr(\QRaw file [foo//x] could not be fetched!);
    like( $raw->{last_nonfatal_error}, qr/Invalid raw file name/ );

    throws_ok { $raw->raw( key => 'foo/./x' ) } qr(\QRaw file [foo/./x] could not be fetched!);
    like( $raw->{last_nonfatal_error}, qr/Invalid raw file name/ );

    throws_ok { $raw->raw( key => 'level2/' ) } qr(\QRaw file [level2/] could not be fetched!);
    like( $raw->{last_nonfatal_error}, qr/Invalid raw file name/ );
};

# try conflicting file names in Raw::Hash
do {
    throws_ok { Chisel::Builder::Raw::Hash->new( hash => { '/foo' => 'bar', 'foo' => 'bar' } ) }
    qr/cannot have multiple files named foo/;
};

# try not being able to find a mountpoint
do {
    my $raw = Chisel::Builder::Raw->new->mount(
        plugin     => Chisel::Builder::Raw::Hash->new( hash => { 'foo' => '2bar', 'abc' => '2123' } ),
        mountpoint => "/level2",
      );
    
    # try a few files that should work
    is( $raw->raw( key => 'level2/foo' ),  '2bar', 'read raw file "level2/foo"' );
    is( $raw->raw( key => 'level2/abc' ),  '2123', 'read raw file "level2/abc"' );

    # try some errors
    throws_ok { $raw->raw( key => 'foo' ) } qr(\QRaw file [foo] could not be fetched!);
    like( $raw->{last_nonfatal_error}, qr!\QCan't find plugin for raw file name [foo]\E! );
};
