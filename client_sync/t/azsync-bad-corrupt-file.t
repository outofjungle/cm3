#!/usr/local/bin/perl -w

# bad-corrupt-file.t -- tests whether azsync notices that a file fetched by zsync ends up on disk with the wrong md5

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 5;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# bucket.bad.corrupt-file has one file and its metadata taken from bucket.tweak (/files/sudoers/MAIN) but
# otherwise it's the same as 'bucket' (including azsync.manifest.json -- so the file won't match the manifest)
#
# this could happen due to a zsync bug, azsync-builddir bug, builder bug, etc

# make sure it won't get pulled down
azsync_dies( "bucket.bad.corrupt-file" );
scratch_is_gone( "'current' does not exist if there is a corrupt file in the bucket" );

# try on top of an existing bucket
azsync_ok( "bucket.tweak" );

# make sure it still doesn't get pulled down
azsync_dies( "bucket.bad.corrupt-file" ); # should fail
scratch_is( "bucket.tweak", "scratch is unchanged after trying to fetch a corrupt bucket" );
