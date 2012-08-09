#!/usr/local/bin/perl -w

# bad-404-zsyncdata.t -- tests whether azsync notices that the zsync metadata (azsync.data) for a file is missing

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 5;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# bucket.bad.404-zsyncdata is missing zsync metadata for /files/motd/MAIN

# make sure it won't get pulled down
azsync_dies( "bucket.bad.404-zsyncdata" );
scratch_is_gone( "'current' does not exist if /files/motd/MAIN is missing zsync metadata" );

# try on top of an existing bucket
azsync_ok( "bucket.nomotd" );

# make sure it still doesn't get pulled down
azsync_dies( "bucket.bad.404-zsyncdata" ); # should fail
scratch_is( "bucket.nomotd", "scratch is unchanged after trying to fetch a corrupt bucket" );

