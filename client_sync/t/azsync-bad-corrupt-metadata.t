#!/usr/local/bin/perl -w

# bad-corrupt-metadata.t -- tests what happens when the .zsync file does not match the corresponding real file

use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 5;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# bucket.bad.corrupt-metadata is the same as 'bucket' except that azsync.data/files/sudoers/MAIN has been
# taken from 'bucket.tweak'

# need an alarm here since this triggers a bug in zsync where it will get wedged and spam the
# web server if the last block of the file does not match the expected checksum
eval {
    local $SIG{'ALRM'} = sub { die "Timeout\n" };

    alarm 20;

    # make sure it won't get pulled down
    azsync_dies( "bucket.bad.corrupt-metadata" );
    scratch_is_gone( "'current' does not exist if there is a corrupt file in the bucket" );

    # try on top of an existing bucket
    azsync_ok( "bucket.tweak" );

    # make sure it still doesn't get pulled down
    azsync_dies( "bucket.bad.corrupt-metadata" ); # should fail
    scratch_is( "bucket.tweak", "scratch is unchanged after trying to fetch a corrupt bucket" );

    alarm 0;
};

if($@) {
    die $@;
}
