#!/usr/local/bin/perl

use warnings;
use strict;
use Digest::MD5 qw/md5_hex/;
use File::Temp qw/tempdir/;
use Test::More tests => 6;
use Test::Differences;
use Test::Exception;
use Test::Workspace qw/:all/;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $ws = Chisel::Workspace->new( dir => wsinit() );

# let's store a few blobs
is( $ws->store_blob( "hello world\n" ), blob( "hello world\n" ), "store_blob #1" );
is( $ws->store_blob( "foo bar baz\n" ), blob( "foo bar baz\n" ), "store_blob #2" );
is( $ws->store_blob( "" ),              blob( "" ),              "store_blob #3" );

# let's cat them back out, just to make sure it worked
is( $ws->cat_blob( blob( "hello world\n" ) ), "hello world\n", "cat_blob #3" );
is( $ws->cat_blob( blob( "foo bar baz\n" ) ), "foo bar baz\n", "cat_blob #3" );
is( $ws->cat_blob( blob( "" ) ),              "",              "cat_blob #3" );
