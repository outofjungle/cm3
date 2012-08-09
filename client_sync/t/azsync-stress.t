#!/usr/local/bin/perl -w

# stress.t -- goes through buckets many times in random order, looking for errors

use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";

# list of buckets to test with
my @buckets = qw/ bucket bucket.nomotd bucket.norepo bucket.tweak bucket.nofiles bucket.symlink bucket.repo-is-directory bucket.zerolength /;

# try every transition
plan tests => (scalar @buckets) ** 2 * 2;

for my $x (@buckets) {
    for my $y (@buckets) {
        wipe_scratch();
        azsync_ok($x);
        azsync_ok($y, message => "transition from $x to $y");
    }
}
