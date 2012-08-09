#!/usr/local/bin/perl -w

# tests that when "chisel_verify -d dir --update-keyrings" is used, keyrings are updated if and only if they're legitimate

use warnings;
use strict;
use Digest::MD5 qw/md5_hex/;
use Test::More tests => 18;
use Test::chiselVerify qw/:all/;

my $kf_orig = "b23d9aed6751b8a583c25cc1aa49ed5495c36e7d00edf9b06614a6f37ed36655";
my $kf_update = "b23d9aed6751b8a583c25cc1aa49ed542c62a2d9353392975341e1c2ce5fc3ea";

my $fixtures = fixtures();

# get a keyring fingerprint and run on the base bucket
is( gnupghome_fingerprint(), $kf_orig );
verify_ok( "-d $fixtures/bucket.normal" );
is( gnupghome_fingerprint(), $kf_orig );

# note that bucket.keyrings-update should NOT verify without --update-keyrings
# (because it has a script which is signed by a new identity)
# also no change should be made to the local gnupghome
verify_dies_like( "-d $fixtures/bucket.keyrings-update", qr/motd: missing human signature/ );
verify_dies_like( "-d $fixtures/bucket.keyrings-update-badsig", qr/motd: missing human signature/ );
is( gnupghome_fingerprint(), $kf_orig );

# that bucket should work with --update-keyrings, and then it should work again WITHOUT --update-keyrings
verify_ok( "-d $fixtures/bucket.keyrings-update --update-keyrings");
verify_ok( "-d $fixtures/bucket.keyrings-update" );
is( gnupghome_fingerprint(), $kf_update ); # it should have been updated

# this should verify now, since the only "bad sig" is on a keyring
# and chisel_verify is supposed to warn & continue
verify_ok( "-d $fixtures/bucket.keyrings-update-badsig" );
is( gnupghome_fingerprint(), $kf_update );

# make sure the original bucket still works, there's no reason it shouldn't
verify_ok( "-d $fixtures/bucket.normal" );
is( gnupghome_fingerprint(), $kf_update );

# make sure keyring update only happens if the keyring actually is valid
# first we need to wipe scratch and start over
wipe_scratch();
is( gnupghome_fingerprint(), $kf_orig ); # just checking

# ok do the test
verify_dies_like( "-d $fixtures/bucket.keyrings-update-badsig --update-keyrings", qr/humanring.gpg: missing two human signatures/ );
is( gnupghome_fingerprint(), $kf_orig ); # that should *not* have updated keyrings

# make sure nothing weird happens on a bucket without keyrings
verify_ok( "-d $fixtures/bucket.normal --update-keyrings" );
is( gnupghome_fingerprint(), $kf_orig );

sub gnupghome_fingerprint { # compute a fingerprint of the local gnupghome
    my $dir = gnupghome();
    open my $afh, "<", "$dir/autoring.gpg" or die "can't open $dir/autoring.gpg: $!\n";
    my $aring = do { local $/; <$afh> };
    close $afh or die "close: $!\n";
    
    open my $hfh, "<", "$dir/humanring.gpg" or die "can't open $dir/humanring.gpg: $!\n";
    my $hring = do { local $/; <$hfh> };
    close $hfh or die "close: $!\n";
    
    return md5_hex($aring) . md5_hex($hring);
}
