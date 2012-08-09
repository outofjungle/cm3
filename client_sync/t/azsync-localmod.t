#!/usr/local/bin/perl -w

# localmod.t -- tests if azsync can repair local tampering

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 4;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# fetch "bucket"
azsync_ok( "bucket" );

# precondition
scratch_is( "bucket" );

# tweak motd
open my $fh, ">>", scratch() . "/current/files/motd/MAIN"
 or die "open motd: $!";
print $fh "extra line\n" or die;
close $fh or die;

# postcondition
scratch_isnt( "bucket" );

# should go back to normal
azsync_ok( "bucket" );
