#!/usr/local/bin/perl -w

# tests the "verify_file" function in Chisel::Integrity

use warnings;
use strict;
use Test::More tests => 31;
use Test::chiselVerify qw/:all/;
use Chisel::Integrity;

# these are the same fixtures used in verify-datadir.t
# this test also sort of helps make sure the fixtures are what we expect :)

my $fixtures = fixtures();

# these all should have decent MANIFEST signatures
is_signed( { file => "$fixtures/bucket.normal/MANIFEST", key => "**", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.bad.badsig-script/MANIFEST", key => "**", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.keyrings-update/MANIFEST", key => "**", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.keyrings-update-badsig/MANIFEST", key => "**", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.bad.mfail-extra-file/MANIFEST", key => "**", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.bad.mfail-missing-file/MANIFEST", key => "**", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.bad.mfail-edited-file/MANIFEST", key => "**", ring => "autoring.gpg" } );

##
# test some fixtures that have good signatures

# test the basics: MANIFEST auto sigs, script human sigs
is_signed( { file => "$fixtures/bucket.normal/MANIFEST", key => "chiselbuilder", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.normal/MANIFEST", key => "chiselsanity", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.normal/scripts/motd", key => "*", ring => "humanring.gpg" } );
is_signed( { file => "$fixtures/bucket.normal/scripts/sudoers", key => "*", ring => "humanring.gpg" } );

# but that's ALL that should be in there
isnt_signed( { file => "$fixtures/bucket.normal/scripts/motd", key => "**", ring => "humanring.gpg" } );
isnt_signed( { file => "$fixtures/bucket.normal/scripts/motd", key => "chiselbuilder", ring => "autoring.gpg" } );
isnt_signed( { file => "$fixtures/bucket.normal/scripts/motd", key => "*", ring => "autoring.gpg" } );

# make sure the star works as expected
is_signed( { file => "$fixtures/bucket.normal/MANIFEST", key => "*", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.normal/MANIFEST", key => "**", ring => "autoring.gpg" } );
isnt_signed( { file => "$fixtures/bucket.normal/MANIFEST", key => "***", ring => "autoring.gpg" } );
isnt_signed( { file => "$fixtures/bucket.normal/MANIFEST", key => "*", ring => "humanring.gpg" } );

# check bucket.keyrings-update and bucket.keyrings-update-badsig
# the latter should have a good manifest and good signature for it
is_signed( { file => "$fixtures/bucket.keyrings-update/MANIFEST", key => "chiselbuilder", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.keyrings-update/MANIFEST", key => "chiselsanity", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.keyrings-update-badsig/MANIFEST", key => "chiselbuilder", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.keyrings-update-badsig/MANIFEST", key => "chiselsanity", ring => "autoring.gpg" } );

# check MANIFEST in bucket.extrasig, it has two extra signatures: 
# one valid but for an unrecognized user, and one invalid but for a recognized user
is_signed( { file => "$fixtures/bucket.extrasig/MANIFEST", key => "chiselbuilder", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.extrasig/MANIFEST", key => "chiselsanity", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.extrasig/MANIFEST", key => "**", ring => "autoring.gpg" } );

##
# test some fixtures that have bad signatures

# in this one, motd has a bad signature
isnt_signed( { file => "$fixtures/bucket.bad.badsig-script/scripts/motd", key => "*", ring => "humanring.gpg" } );
is_signed( { file => "$fixtures/bucket.bad.badsig-script/scripts/sudoers", key => "*", ring => "humanring.gpg" } );

# in this one, the manifest has no builder signature
isnt_signed( { file => "$fixtures/bucket.bad.no-builder-signature/MANIFEST", key => "chiselbuilder", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.bad.no-builder-signature/MANIFEST", key => "chiselsanity", ring => "autoring.gpg" } );

# in this one the manifest has no signature file at all
isnt_signed( { file => "$fixtures/bucket.bad.nosig-manifest/MANIFEST", key => "*", ring => "autoring.gpg" } );
is_signed( { file => "$fixtures/bucket.bad.nosig-manifest/scripts/motd", key => "*", ring => "humanring.gpg" } );
