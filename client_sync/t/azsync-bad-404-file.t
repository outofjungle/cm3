#!/usr/local/bin/perl -w

# bad-404-file.t -- tests whether azsync notices that a file on the server is missing

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 5;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# bucket.bad.404-file is missing /files/motd/MAIN

# make sure it won't get pulled down
azsync_dies( "bucket.bad.404-file" );
scratch_is_gone( "'current' does not exist if the bucket is missing /files/motd/MAIN" );

# try on top of an existing bucket
azsync_ok( "bucket.nomotd" );

# make sure it still doesn't get pulled down
azsync_dies( "bucket.bad.404-file" ); # should fail
scratch_is( "bucket.nomotd", "scratch is unchanged after trying to fetch a corrupt bucket" );
