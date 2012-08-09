#!/usr/local/bin/perl -w

# symlink.t -- tests whether azsync can make symlinks

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 7;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# checking existence of the symlink 'VERSION' -> 'xxx'

# should start existing
azsync_ok( "bucket.symlink" );
is( readlink "$AZSYNC_SCRATCH/current/VERSION", "xxx", "VERSION is a link to xxx" );

# should not be relinked by a bad bucket
azsync_dies( "bucket.evil-manifest-links" );
scratch_is( "bucket.symlink" );
is( readlink "$AZSYNC_SCRATCH/current/VERSION", "xxx", "VERSION is still a link to xxx" );

# make sure we can get rid of it
azsync_ok( "bucket" );
ok( ! -l "$AZSYNC_SCRATCH/current/VERSION", "VERSION is no longer a symlink" );
