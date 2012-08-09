#!/usr/local/bin/perl -w

# rmfile.t -- tests whether azsync can remove files and then add them back

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 6;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# checking existence of 'REPO'

# should start existing
azsync_ok( "bucket" );
ok( -f "$AZSYNC_SCRATCH/current/REPO", "REPO exists at the start" );

# should go away
azsync_ok( "bucket.norepo" );
ok( ! -f "$AZSYNC_SCRATCH/current/REPO", "REPO is gone" );

# then come back
azsync_ok( "bucket" );
ok( -f "$AZSYNC_SCRATCH/current/REPO", "REPO came back" );
