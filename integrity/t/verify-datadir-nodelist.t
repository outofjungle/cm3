#!/usr/local/bin/perl -w

# tests the NODELIST check done by commands like "chisel_verify -d dir"

use warnings;
use strict;
use Test::More tests => 2;
use Test::chiselVerify qw/:all/;

my $fixtures = fixtures();

verify_ok( "-d $fixtures/bucket.normal --use-hostname verify-test-a.example.com" );
verify_dies_like( "-d $fixtures/bucket.normal --use-hostname verify-fail.example.com", qr/hostname missing: verify-fail\.example\.com/ );
