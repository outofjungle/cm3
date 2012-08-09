#!/usr/local/bin/perl -w

# chmod.t -- tests whether azsync can chmod a file and then chmod it back

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 6;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";
    
# checking the permissions on 'REPO'
my $perm;

# should start as 0644
azsync_ok( "bucket" );
$perm = ( stat "$AZSYNC_SCRATCH/current/REPO" )[2] & 07777
  or die "can't stat REPO: $!";
is( $perm, 0644, "REPO starts as 0644" );

# and tweak to 0666
azsync_ok( "bucket.tweak" );
$perm = ( stat "$AZSYNC_SCRATCH/current/REPO" )[2] & 07777
  or die "can't stat REPO: $!";
is( $perm, 0666, "REPO tweaks to 0666" );

# go back
azsync_ok( "bucket" );
$perm = ( stat "$AZSYNC_SCRATCH/current/REPO" )[2] & 07777
  or die "can't stat REPO: $!";
is( $perm, 0644, "REPO goes back to 0644" );
