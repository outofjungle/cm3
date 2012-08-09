#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 1;
use Test::Differences;
use Digest::MD5 qw/md5_hex/;
use ChiselTest::Engine;
use Log::Log4perl;

my $engine = ChiselTest::Engine->new;
my $checkout = $engine->new_checkout;
my %transforms = map { $_->name => $_ } $checkout->transforms;
my @raws = $checkout->raw;
my $generator = $engine->new_generator;

my $result = $generator->generate(
    targets => [
        # build with DEFAULT, this is enough in transforms.binary
        { transforms => [ @transforms{ qw! func/BINARY ! } ] , file => 'files/fake.png/MAIN' },
        { transforms => [ @transforms{ qw! func/BINARY ! } ] , file => 'files/rawtest/MAIN' },
    ],
    raws => \@raws,
);

eq_or_diff(
    $result,
    [
        # fake.png
        { ok => 1, blob => '8c8c0b4336192e56423048c7a7b604e722fe579e' },

        # rawtest (a text file, for a control test)
        { ok => 1, blob => 'e5c5c5583f49a34e86ce622b59363df99e09d4c6' },
    ]
);
