#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 1;
use Test::Differences;
use Digest::MD5 qw/md5_hex/;
use ChiselTest::Engine;
use Log::Log4perl;

my $engine = ChiselTest::Engine->new;
my $checkout = $engine->new_checkout( transformdir => "t/files/configs.1/transforms" );
my %transforms = map { $_->name => $_ } $checkout->transforms;
my $raws = [$checkout->raw];
my $generator = $engine->new_generator;

my $result = $generator->generate(
    targets => [
        { transforms => [ @transforms{qw! DEFAULT func/UNICODE !} ], file => 'files/motd/MAIN' },
        { transforms => [ @transforms{qw! func/UNICODE !} ],         file => 'files/homedir/MAIN' },
    ],
    raws => $raws,
);

eq_or_diff(
    $result,
    [
        # motd
        { ok => 1, blob => Chisel::Workspace->git_sha( 'blob', <<'EOT' ) },
שלום העולם
SMILE :) ☻ ☺
EOT
        # homedir
        { ok => 1, blob => Chisel::Workspace->git_sha( 'blob', <<'EOT' ) },
---
johndoe:
  - '♥'
  - '❦'
EOT
    ]
);
