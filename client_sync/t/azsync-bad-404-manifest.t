#!/usr/local/bin/perl -w

# bad-404-manifest.t -- tests whether azsync notices that the manifest on the server is missing

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 5;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# bucket.bad.404-manifest is missing azsync.manifest.json

# make sure it won't get pulled down
azsync_dies( "bucket.bad.404-manifest" );
scratch_is_gone( "'current' does not exist if the bucket is missing a manifest" );

# try on top of an existing bucket
azsync_ok( "bucket" );

# make sure it still doesn't get pulled down
azsync_dies( "bucket.bad.404-manifest" ); # should fail
scratch_is( "bucket", "scratch is unchanged after trying to fetch a corrupt bucket" );
