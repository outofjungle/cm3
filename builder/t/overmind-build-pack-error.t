#!/usr/bin/perl -w

# overmind-build-pack-error.t -- test overmind when packer has an error

use strict;
use warnings;

use ChiselTest::Overmind qw/:all/;
use Test::More tests => 18;

my $overmind = tco_overmind;
my $zkl      = $overmind->engine->new_zookeeper_leader;
$zkl->update_part(
    worker => 'worker0',
    part   => [qw! bar1 foo1 foo2 !],
);

# First run
$overmind->run_once;
nodelist_is( [qw! bar1 foo1 foo2 !] );
blob_is( 'bar1', '.bucket/transforms-index', '["DEFAULT","func/BAR","host/bar1","DEFAULT_TAIL"]' );
blob_is( 'foo1', '.bucket/transforms-index', '["DEFAULT","func/FOO","DEFAULT_TAIL"]' );
blob_is( 'foo2', '.bucket/transforms-index', '["DEFAULT","func/FOO","DEFAULT_TAIL"]' );

# Trigger a pack error.
$ChiselTest::Overmind::Overmind2::OV_PACK_ERROR = 'OH NO';
$overmind->host( 'bar1' )->transformset->needs_pack( 1 );

# Second run
$overmind->run_once;
nodelist_is( [qw! bar1 foo1 foo2 !] );
blob_is( 'bar1', '.bucket/transforms-index', undef );
blob_is( 'bar1', '.error',                   "OH NO\n" );
blob_is( 'foo1', '.bucket/transforms-index', '["DEFAULT","func/FOO","DEFAULT_TAIL"]' );
blob_is( 'foo2', '.bucket/transforms-index', '["DEFAULT","func/FOO","DEFAULT_TAIL"]' );

# Undo pack error. But this shouldn't cause a re-pack immediately.
undef $ChiselTest::Overmind::Overmind2::OV_PACK_ERROR;

# Third run. Nothing should change.
$overmind->run_once;
nodelist_is( [qw! bar1 foo1 foo2 !] );
blob_is( 'bar1', '.bucket/transforms-index', undef );
blob_is( 'bar1', '.error',                   "OH NO\n" );
blob_is( 'foo1', '.bucket/transforms-index', '["DEFAULT","func/FOO","DEFAULT_TAIL"]' );
blob_is( 'foo2', '.bucket/transforms-index', '["DEFAULT","func/FOO","DEFAULT_TAIL"]' );

# Force a repack by setting the needs_pack flag.
$overmind->host( 'bar1' )->transformset->needs_pack( 1 );

# Fourth run.
$overmind->run_once;
nodelist_is( [qw! bar1 foo1 foo2 !] );
blob_is( 'bar1', '.bucket/transforms-index', '["DEFAULT","func/BAR","host/bar1","DEFAULT_TAIL"]' );
blob_is( 'foo1', '.bucket/transforms-index', '["DEFAULT","func/FOO","DEFAULT_TAIL"]' );
blob_is( 'foo2', '.bucket/transforms-index', '["DEFAULT","func/FOO","DEFAULT_TAIL"]' );
