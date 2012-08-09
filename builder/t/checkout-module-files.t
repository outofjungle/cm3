#!/usr/bin/perl

# checkout-module-files.t -- test referring to scripts and files bundled with modules

use warnings;
use strict;
use Test::More tests => 3;
use Test::Differences;
use ChiselTest::Engine;

my $engine = ChiselTest::Engine->new;
my $checkout = $engine->new_checkout;

# $checkout->raw should realize it needs two module-specific files (one script, one bundle file)
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
    ]
);

# Confirm contents of a bundled file
is( $raws[3]->name, "passwd.bundle/base" );
is( $raws[3]->data, "root:*:0:0:System Administrator:/var/root:/bin/sh\n" );
