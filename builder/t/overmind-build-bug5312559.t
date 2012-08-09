#!/usr/bin/perl -w

# regression test for http://bug.corp.fake-domain.com/show_bug.cgi?id=5312559
# "raw files deleted too early when transforms stop referencing them"

use strict;
use warnings;

use ChiselTest::Overmind qw/:all/;
use Test::More tests => 6;

my $overmind = tco_overmind;
my $zkl      = $overmind->engine->new_zookeeper_leader;
$zkl->update_part(
    worker => 'worker0',
    part   => [qw! u0 !],
);

# Handle to CheckoutPack
my $cp = Chisel::CheckoutPack->new( filename => $overmind->engine->config( "var" ) . "/dropbox/checkout-p0.tar" );
my $cpe = $cp->extract;

# First run
$overmind->run_once;
nodelist_is( [qw! u0 !] );
blob_is( 'u0', 'files/motd/MAIN', <<'EOT' );
שלום העולם
SMILE :) ☻ ☺
EOT
blob_is( 'u0', '.error', undef );

# Remove raw file "unicode", and stop using it in transforms, at the same time
my $smash = tco_smash0;
$smash->{raws} = [ grep { $_->name ne 'unicode' } @{ $smash->{raws} } ];
my $u0_transforms = $smash->{host_transforms}{u0};
for (my $i = 0; $i < @$u0_transforms; $i++) {
    if($u0_transforms->[$i]->name eq 'func/UNICODE') {
        $u0_transforms->[$i] = Chisel::Transform->new(
            name => 'func/UNICODE',
            yaml => <<'EOT',
motd:
    - [ replace, "hello world", "你好世界" ]
    - [ replace, "你好世界", "שלום העולם" ]
EOT
        );
    }
}

# Re-write CheckoutPack
sleep 1;
$cpe->smash( %$smash );
$cp->write_from_fs( $cpe->stagedir );

# Second run
$overmind->run_once;
nodelist_is( [qw! u0 !] );
blob_is( 'u0', 'files/motd/MAIN', "שלום העולם\n" );
blob_is( 'u0', '.error', undef );
