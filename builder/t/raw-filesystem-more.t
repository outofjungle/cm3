#!/usr/bin/perl

# this used to be in generator-readraw.t, but was moved since generator no longer supports arbitrary raw objects

use warnings;
use strict;
use Test::More tests => 19;
use Test::Differences;
use Test::Exception;
use Chisel::Builder::Raw::Filesystem;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

# these variables are declared out here since ok_cant_readraw needs it
my $fsobj;
my $current_rawdir;

# try a rawdir that exists
do {
    $current_rawdir = "t/files/configs.readraw/raw";
    
    $fsobj = Chisel::Builder::Raw::Filesystem->new( rawdir => $current_rawdir );

    # this file should work
    my $rawtest = $fsobj->fetch( "subdir/file" );
    is( "a file\n", $rawtest, "readraw on a normal file" );

    # paths that don't exist shouldn't work!
    ok( ! defined $fsobj->fetch( "nonexistent" ), "readraw fails on a file that doesn't exist" );
    like( $fsobj->last_nonfatal_error, qr/file does not exist: nonexistent/, "readraw fails on a file that doesn't exist" );

    # symlinks to OK files should work
    my $linktest = $fsobj->fetch( "file.link" );
    is( "a file\n", $linktest, "readraw on a symlink" );

    # empty string, undef shouldn't work!
    throws_ok { $fsobj->fetch() } qr/no file name provided/;
    throws_ok { $fsobj->fetch("") } qr/no file name provided/;

    # paths with .. shouldn't work!
    ok_exists_but_readraw_not_found( "../notraw/notfile", qr/unsafe pathspec/ );
    ok_exists_but_readraw_not_found( "subdir/../../notraw/notfile", qr/unsafe pathspec/ );
    ok_exists_but_readraw_not_found( "../../../../../../../../../../../../../etc/resolv.conf", qr/unsafe pathspec/ );

    # symlinks with dots shouldn't work!
    ok_exists_but_readraw_not_found( "notfile.link", qr/unsafe pathspec/ );
    ok_exists_but_readraw_not_found( "notraw.link/notfile", qr/unsafe pathspec/ );

    # absolute symlinks shouldn't work!
    ok_exists_but_readraw_not_found( "resolv.link", qr/unsafe pathspec/ );
};

# try a rawdir that doesn't exist
do {
    $current_rawdir = "/fakepath/nonexistent";
    
    $fsobj = Chisel::Builder::Raw::Filesystem->new( rawdir => $current_rawdir );
    
    ok( ! -e "/fakepath/nonexistent" );
    
    # nothing should work in this rawdir
    ok_cant_readraw( "", qr/no file name provided/ );
    ok_cant_readraw( "nonexistent", qr/rawdir not real: \/fakepath\/nonexistent/ );
    
    # try some funny business with /etc/resolv.conf
    ok( -r "/etc/resolv.conf", "/etc/resolv.conf must be readable for this test" );
    
    ok_cant_readraw( "/etc/resolv.conf", qr/rawdir not real: \/fakepath\/nonexistent/ );
    ok_cant_readraw( "../../../etc/resolv.conf", qr/rawdir not real: \/fakepath\/nonexistent/ );
    ok_cant_readraw( "/../../../etc/resolv.conf", qr/rawdir not real: \/fakepath\/nonexistent/ );
};

sub ok_cant_readraw {
    my ( $file, $error_re ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    
    my $message = "readraw fails on $file with rawdir=$current_rawdir";
    
    my $r1 = eval { $fsobj->fetch( $file ); 1; };
    my $err1 = $@;

    my $r2 = eval { $fsobj->fetch( $file ); 1; };
    my $err2 = $@;

    subtest $message => sub {
        plan tests => 4;
        ok( ! defined $r1 );
        ok( ! defined $r2 );
        like( $err1, $error_re );
        like( $err2, $error_re );
    };
}

sub ok_exists_but_readraw_not_found {
    my ( $file, $error_re ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $message = "readraw fails on $file with rawdir=$current_rawdir even though it exists";

    if( -f "$current_rawdir/$file" ) {
        subtest $message => sub {
            plan tests => 4;

            my $r1 = $fsobj->fetch( $file );
            ok( !defined $r1 );
            like( $fsobj->last_nonfatal_error, $error_re );

            my $r2 = $fsobj->fetch( $file );
            ok( !defined $r2 );
            like( $fsobj->last_nonfatal_error, $error_re );
        };
    } else {
        diag( "$current_rawdir/$file does not exist" );
        fail( $message );
    }
}
