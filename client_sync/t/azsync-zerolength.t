#!/usr/local/bin/perl -w

# zerolength.t -- tests whether azsync can fetch zero length files

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 5;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# checking existence of the symlink 'VERSION' -> 'xxx'

# should sync down fine
azsync_ok( "bucket.zerolength" );

# just make sure
ok( -z "$AZSYNC_SCRATCH/current/zerolength", "'zerolength' is zero length" );
ok( -s "$AZSYNC_SCRATCH/current/normal", "'normal' is not zero length" );

# make sure we can get rid of it
azsync_ok( "bucket" );
ok( ! -f "$AZSYNC_SCRATCH/current/zerolength", "'zerolength' can be removed" );
