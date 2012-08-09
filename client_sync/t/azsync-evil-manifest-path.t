#!/usr/local/bin/perl -w

# evil-manifest-path.t -- test what happens if the azsync manifest refers to paths outside of its directory

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 6;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# bucket.bad.evil-manifest-path refers to ../NODELIST and xxx/../../VERSION

# make sure it won't get pulled down
azsync_dies( "bucket.bad.evil-manifest-path" );
scratch_is_gone( "'current' does not exist if the manifest refers to upwards paths" );

# ensure it didn't write anything anywhere
my $AZSYNC_SCRATCH = scratch();
is( "", scalar qx[find $AZSYNC_SCRATCH -type f], "no files were left in scratch" );

# try on top of an existing bucket
azsync_ok( "bucket.tweak" );

# make sure it still doesn't get pulled down
azsync_dies( "bucket.bad.evil-manifest-path" );
scratch_is( "bucket.tweak", "scratch is unchanged after trying to fetch a corrupt bucket" );
