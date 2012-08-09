#!/usr/local/bin/perl -w

# basic.t -- fetches a bucket twice, then fetches another twice

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 3;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# fetch "bucket" twice
azsync_ok( "bucket" );
azsync_ok( "bucket" );
scratch_is( "bucket" );
