#!/usr/local/bin/perl -w

# tests the "verify_manifest" function in Chisel::Integrity, by running it on the bucket fixtures in t/files

use warnings;
use strict;
use Test::More tests => 15;
use Test::chiselVerify qw/:all/;
use Chisel::Integrity;

# basic tests run against some fixtures
# these are the same ones used in verify-datadir.t, but different success/failure patterns
# (we're only checking the manifest here, not gpg signatures)

my $fixtures = fixtures();

my $m = Chisel::Integrity->new( gnupghome => gnupghome() );

# these all should be totally okay
ok( $m->verify_manifest( dir => "$fixtures/bucket.normal" ) );
ok( $m->verify_manifest( dir => "$fixtures/bucket.extrasig" ) );

# these should have valid manifests, but something wrong with signatures
ok( $m->verify_manifest( dir => "$fixtures/bucket.bad.badsig-manifest" ) );
ok( $m->verify_manifest( dir => "$fixtures/bucket.bad.badsig-script" ) );
ok( $m->verify_manifest( dir => "$fixtures/bucket.bad.no-builder-signature" ) );
ok( $m->verify_manifest( dir => "$fixtures/bucket.bad.no-sanity-signature" ) );
ok( $m->verify_manifest( dir => "$fixtures/bucket.bad.nosig-manifest" ) );
ok( $m->verify_manifest( dir => "$fixtures/bucket.bad.nosig-script" ) );
ok( $m->verify_manifest( dir => "$fixtures/bucket.keyrings-update" ) );
ok( $m->verify_manifest( dir => "$fixtures/bucket.keyrings-update-badsig" ) );

# these should have invalid manifests
ok( ! $m->verify_manifest( dir => "$fixtures/bucket.bad.no-manifest" ) );
ok( ! $m->verify_manifest( dir => "$fixtures/bucket.bad.mfail-extra-file" ) );
ok( ! $m->verify_manifest( dir => "$fixtures/bucket.bad.mfail-missing-file" ) );
ok( ! $m->verify_manifest( dir => "$fixtures/bucket.bad.mfail-edited-file" ) );

# this doesn't even exist
ok( ! $m->verify_manifest( dir => "t/files/nonexistent" ) );
