#!/usr/bin/perl

# checkout-raw.t -- test raw-file-related functions of the Checkout class

use warnings;
use strict;
use Test::More tests => 9;
use Test::Differences;
use Test::Exception;
use ChiselTest::Engine;
use Log::Log4perl;

my $engine = ChiselTest::Engine->new;
my $checkout = $engine->new_checkout;

# extract all raw files referenced by these transforms
my %raw_needed = map { $_ => 1 }    # remove duplicates by assigning to a hash
  map  { $_->raw_needed() }         # all raw files needed by each transform
  grep { $_->is_good() }            # skip transforms that are unloadable
  $checkout->transforms;

eq_or_diff(
    [ sort keys %raw_needed ],
    [
        qw!
          modules/passwd/passwd.1
          nonexistent
          passwd
          passwd.bundle/base
          rawtest
          unicode
          fake.png
          !
    ],
    "raw file list referenced by transforms"
);

# test $checkout
do {
    # extract all "interesting" raw files
    # this should NOT include rawtest2
    my @raws = sort { $a->name cmp $b->name } $checkout->raw;
    eq_or_diff(
        [ map { $_->name } @raws ],
        [
            qw!
              modules/passwd/passwd.1
              nonexistent
              passwd
              passwd.bundle/base
              rawtest
              unicode
              fake.png
              !
        ],
        "interesting raw file names"
    );

    # inspect a couple of these objects
    eq_or_diff( $raws[0],
        Chisel::RawFile->new( name => "modules/passwd/passwd.1", data => "passwd.1 script\n", ts => $raws[0]->ts )
    );
    eq_or_diff( $raws[1], Chisel::RawFile->new( name => "nonexistent", data => undef, ts => $raws[1]->ts ) );
    eq_or_diff(
        $raws[3],
        Chisel::RawFile->new(
            name => "passwd.bundle/base",
            data => "root:*:0:0:System Administrator:/var/root:/bin/sh\n",
            ts   => $raws[3]->ts
        )
    );

    # try reading some raw files using Checkout->raw
    is( $checkout->raw( "rawtest" )->data, "line one\nline two\n", "raw('rawtest')" );
    is( $checkout->raw( "rawtest2" )->data, "line three\n", "raw('rawtest2')" );
    throws_ok { $checkout->raw( "nonexistent" ) } qr/file does not exist: nonexistent/,
      "raw('nonexistent')";
    throws_ok { $checkout->raw( "nonexistent2" ) } qr/file does not exist: nonexistent2/,
      "raw('nonexistent2')";
};
