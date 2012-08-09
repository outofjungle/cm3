#!/usr/local/bin/perl -w

# tests the VERSION check done by commands like "chisel_verify -d dir"

use warnings;
use strict;
use Test::More tests => 6;
use Test::chiselVerify qw/:all/;

# note that the fixtures have VERSION = 1254174524

my $fixtures = fixtures();

write_version("1254174524\n"); # new = old
verify_ok( "-d $fixtures/bucket.normal", "verify works with equal version" );

write_version("1254174523\n"); # new > old
verify_ok( "-d $fixtures/bucket.normal", "verify works on a version upgrade" );

write_version("1254174525\n"); # new < old
verify_dies_like( "-d $fixtures/bucket.normal", qr/version check failed: 1254174524 < 1254174525/, "verify fails on a version downgrade" );

write_version(undef); # old version does not exist
verify_ok( "-d $fixtures/bucket.normal", "verify works if old version is unknown" );

write_version("abc\n"); # old is nonsense
verify_ok( "-d $fixtures/bucket.normal", "verify works if old version is not a number" );

write_version(""); # old is empty
verify_ok( "-d $fixtures/bucket.normal", "verify works if old version is zero-length" );
