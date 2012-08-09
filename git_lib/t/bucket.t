#!/usr/local/bin/perl

# bucket.t -- tests very basic bucket behaviors, like constructor and stringification

use warnings;
use strict;
use Digest::MD5 qw/md5_hex/;
use File::Temp qw/tempdir/;
use Test::More tests => 5;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Bucket"); }

# too many parameters should die
throws_ok { my $bucket = Chisel::Bucket->new( badparam => 0 ); } qr/^Too many parameters/, "Bucket->new dies with unrecognized parameters";

# test constructor with no arguments
do {
    # start with an empty bucket
    my $bucket = Chisel::Bucket->new();

    # try stringification
    is( "$bucket", '4b825dc642cb6eb9a060e54bf8d69288fbee4904', "bucket stringifies as a sha1sum" );

    # try manifest() and manifest_json()
    eq_or_diff( $bucket->manifest,      {}, "manifest() starts as an empty hash" );
    eq_or_diff( $bucket->manifest_json, "", "manifest_json() starts as an empty string" );
};
