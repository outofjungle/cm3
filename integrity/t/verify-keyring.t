#!/usr/local/bin/perl -w

# tests commands like "chisel_verify -R file", which are used to verify new keyrings

use warnings;
use strict;
use Test::More tests => 8;
use Test::chiselVerify qw/:all/;

my $gnupghome = gnupghome();
my $fixtures = fixtures();

# the keyrings in bucket.keyrings-update should all be valid
verify_ok( "-R $fixtures/bucket.keyrings-update/files/keyrings/autoring.gpg" );
verify_ok( "-R $fixtures/bucket.keyrings-update/files/keyrings/humanring.gpg" );

# the human keyring in bucket.keyrings-update-badsig is invalid
verify_ok( "-R $fixtures/bucket.keyrings-update-badsig/files/keyrings/autoring.gpg" );
verify_dies_like( "-R $fixtures/bucket.keyrings-update-badsig/files/keyrings/humanring.gpg", qr/humanring.gpg: missing two human signatures/ );

# scripts should NOT be valid keyrings
verify_dies_like( "-R $fixtures/bucket.normal/scripts/motd", qr/motd: missing two human signatures/ );
verify_dies_like( "-R $fixtures/bucket.normal/scripts/sudoers", qr/sudoers: missing two human signatures/ );

# manifest should NOT be a valid keyring
verify_dies_like( "-R $fixtures/bucket.normal/MANIFEST", qr/MANIFEST: missing two human signatures/ );

# fake files should NOT be valid keyrings
verify_dies_like( "-R $fixtures/bucket.normal/nonexistent", qr/nonexistent: file is not readable/ );
