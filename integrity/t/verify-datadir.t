#!/usr/local/bin/perl -w

# tests commands like "chisel_verify -d dir", which are used to verify new buckets

use warnings;
use strict;
use Test::More tests => 15;
use Test::chiselVerify qw/:all/;

# basic tests run against some fixtures

my $fixtures = fixtures();

# this should be totally okay
verify_ok( "-d $fixtures/bucket.normal" );
verify_ok( "-d $fixtures/bucket.extrasig" );

# these should have valid manifests, but something wrong with signatures
verify_dies_like( "-d $fixtures/bucket.bad.badsig-manifest",      qr/badsig-manifest: could not verify builder signature/ );
verify_dies_like( "-d $fixtures/bucket.bad.badsig-script",        qr/motd: missing human signature/ );
verify_dies_like( "-d $fixtures/bucket.bad.no-builder-signature", qr/no-builder-signature: could not verify builder signature/ );
verify_dies_like( "-d $fixtures/bucket.bad.no-sanity-signature",  qr/no-sanity-signature: could not verify sanity signature/ );
verify_dies_like( "-d $fixtures/bucket.bad.nosig-manifest",       qr/nosig-manifest: could not verify builder signature/ );
verify_dies_like( "-d $fixtures/bucket.bad.nosig-script",         qr/motd: missing human signature/ );
verify_dies_like( "-d $fixtures/bucket.keyrings-update",          qr/motd: missing human signature/ );
verify_dies_like( "-d $fixtures/bucket.keyrings-update-badsig",   qr/motd: missing human signature/ );

# these should have invalid manifests
verify_dies_like( "-d $fixtures/bucket.bad.no-manifest", qr/bucket.bad.no-manifest: invalid manifest/ );
verify_dies_like( "-d $fixtures/bucket.bad.mfail-extra-file", qr/bucket.bad.mfail-extra-file: invalid manifest/ );
verify_dies_like( "-d $fixtures/bucket.bad.mfail-missing-file", qr/mfail-missing-file: invalid manifest/ );
verify_dies_like( "-d $fixtures/bucket.bad.mfail-edited-file", qr/mfail-edited-file: invalid manifest/ );

# this doesn't even exist
verify_dies_like( "-d t/files/nonexistent", qr/nonexistent: directory does not exist/ );
