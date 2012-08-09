#!/usr/local/bin/perl

use warnings;
use strict;
use Digest::MD5 qw/md5_hex/;
use File::Temp qw/tempdir/;
use Test::More tests => 4;
use Test::Differences;
use Test::Exception;
use Test::Workspace qw/:all/;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $ws = Chisel::Workspace->new( dir => wsinit() );

# we need to store a few blobs in order for the buckets to work
is( $ws->store_blob( "hello world\n" ), blob( "hello world\n" ), "store_blob #1" );
is( $ws->store_blob( "foo bar baz\n" ), blob( "foo bar baz\n" ), "store_blob #2" );
is( $ws->store_blob( "" ),              blob( "" ),              "store_blob #3" );

my $bucket = Chisel::Bucket->new;
$bucket->add( file => 'x/z', blob => blob( "hello world\n" ) );
$bucket->add( file => 'y',   blob => blob( "foo bar baz\n" ) );

# this should have the side effect of changing $bucket's name
$ws->store_bucket($bucket);

# check that it worked, we happen to know what this sha should be
is( "$bucket", "a5ee07b35fd07f5af26aaffe9eac0674baa17eba", "store_bucket gave us the right sha" );
