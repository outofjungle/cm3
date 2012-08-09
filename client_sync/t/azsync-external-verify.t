#!/usr/local/bin/perl -w

# external-verify.t -- tests whether azsync's --external-verify option works

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 16;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";
    
# see what happens when external-verify fails the first time
azsync_dies( "bucket", 'external-verify' => 'ls /nonexistent' ); # should fail
scratch_is_gone( "'current' does not exist if external-verify exists on the first request" );

# let it work
azsync_ok( "bucket", 'external-verify' => 'ls /' ); # should succeed

# ok fail it again, but with different buckets
for my $newbucket ( qw/ bucket.nomotd bucket.norepo bucket.tweak bucket.nofiles / ) {
    azsync_dies( $newbucket, 'external-verify' => 'ls /nonexistent' ); # should fail
    scratch_is( "bucket", "when external-verify fails on $newbucket, nothing is changed" );
}

# ok now let it succeed, and finally go back to where we started
for my $newbucket ( qw/ bucket.nomotd bucket.norepo bucket.tweak bucket.nofiles bucket / ) {
    azsync_ok( $newbucket, 'external-verify' => 'ls /' ); # should work
}
