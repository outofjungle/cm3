#!/usr/local/bin/perl -w

# repo-is-directory.t -- tests whether azsync can changes files to directories and vice versa

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 8;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# checking existence of the symlink 'VERSION' -> 'xxx'

# should sync down fine
azsync_ok( "bucket.repo-is-directory" );

# make sure it's a dir
ok( -d "$AZSYNC_SCRATCH/current/REPO", "'REPO' is a directory" );
ok( -f "$AZSYNC_SCRATCH/current/REPO/hello", "'REPO/hello' exists" );

# convert to a file
azsync_ok( "bucket" );
ok( -f "$AZSYNC_SCRATCH/current/REPO", "'REPO' is converted to a file" );

# convert back to a dir
azsync_ok( "bucket.repo-is-directory" );
ok( -d "$AZSYNC_SCRATCH/current/REPO", "'REPO' is converted back to a directory" );
ok( -f "$AZSYNC_SCRATCH/current/REPO/hello", "'REPO/hello' exists" );
