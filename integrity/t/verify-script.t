#!/usr/local/bin/perl -w

# tests commands like "chisel_verify -s script", which are used to verify scripts

use warnings;
use strict;
use Test::More tests => 9;
use Test::chiselVerify qw/:all/;

my $fixtures = fixtures();

# scripts in here should be totally okay
verify_ok( "-S $fixtures/bucket.normal/scripts/motd" );
verify_ok( "-S $fixtures/bucket.normal/scripts/sudoers" );

# MANIFEST should not be okay (no human signature)
verify_dies_like( "-S $fixtures/bucket.normal/MANIFEST", qr/MANIFEST: missing human signature/ );

# this isn't even signed
verify_dies_like( "-S $fixtures/bucket.normal/files/motd/MAIN", qr/MAIN: missing human signature/ );

# in this fixture, motd is bad but sudoers is good
verify_dies_like( "-S $fixtures/bucket.bad.badsig-script/scripts/motd", qr/motd: missing human signature/ );
verify_ok( "-S $fixtures/bucket.bad.badsig-script/scripts/sudoers" );

# nonexistent file
verify_dies_like( "-S $fixtures/bucket.bad.badsig-script/nonexistent", qr/nonexistent: file is not readable/ );

# try switching autoring.gpg and humanring.gpg, this should have the effect of making MANIFEST ok but scripts/sudoers not
rename gnupghome() . "/autoring.gpg", gnupghome() . "/autoring.gpg.bak"
  or die "can't back up autoring.gpg\n";
rename gnupghome() . "/humanring.gpg", gnupghome() . "/autoring.gpg"
  or die "can't rename humanring => autoring\n";
rename gnupghome() . "/autoring.gpg.bak", gnupghome() . "/humanring.gpg"
  or die "can't rename autoring.gpg.bak => humanring.gpg\n";

verify_ok( "-S $fixtures/bucket.normal/MANIFEST" );
verify_dies_like( "-S $fixtures/bucket.normal/scripts/sudoers", qr/sudoers: missing human signature/ );
