#!/usr/bin/perl -w

# overmind-build.t -- high-level test of the overmind, runs a basic build end-to-end

use strict;

use AnyEvent;
use Log::Log4perl;
use ChiselTest::Overmind qw/:all/;
use Test::Differences;
use Test::More tests => 26;

my $overmind = tco_overmind;
my $zkl = $overmind->engine->new_zookeeper_leader;
$zkl->update_part(
    worker => 'worker0',
    part   => [ 'bad0', 'bar1', 'barqux1', 'bin0', 'foo1', 'foo2', 'fooqux1', 'invalid1', 'mb0', 'u0' ],
);

# Run a build through once
$overmind->run_once;

# Do a ton of checks on it:

# Check node list in master
nodelist_is( [ qw! bad0 bar1 barqux1 bin0 foo1 foo2 fooqux1 invalid1 mb0 u0 ! ] );

# Check bucket for bad0
nodefiles_are( 'bad0', [qw! .error ! ] );
blob_is( 'bad0', '.error',   "file does not exist: nonexistent\n" );

my %expected = %{ YAML::XS::LoadFile( 't/files/expected.yaml' ) };

# Check bucket for fooqux1
blob_is( 'fooqux1', 'NODELIST', "fooqux1\n" );
blob_like( 'fooqux1', 'REPO',    qr!^\QURL: svn+ssh://example.com/qwer\E$!m );
blob_like( 'fooqux1', 'VERSION', qr/^\d+$/ );
blob_is( 'fooqux1', '.bucket/transforms-index', '["DEFAULT","func/FOO","func/QUX","DEFAULT_TAIL"]' );
blobsha_is( 'fooqux1', '.bucket/transforms/DEFAULT',      '05c23445ef27b1dfe3721899b24e91d7df6a1fdc' );
blobsha_is( 'fooqux1', '.bucket/transforms/func/FOO',     'cff4723c1e4545a2cec9220c64e30a639ccc6dba' );
blobsha_is( 'fooqux1', '.bucket/transforms/func/QUX',     '03e9a760575a2eaaba907d3b4321871b1190a7d2' );
blobsha_is( 'fooqux1', '.bucket/transforms/DEFAULT_TAIL', '1d8ff62ef10931b76611097844a52f9d0ea936b1' );
blob_is( 'fooqux1', "$_", $_->{'blob'} ) for grep { $expected{'fooqux'}{$_}{'blob'} } values %{ $expected{'fooqux'} };
nodefiles_are(
    'fooqux1',
    [
        sort qw!MANIFEST MANIFEST.asc NODELIST REPO VERSION!,
        qw! .bucket/transforms-index .bucket/transforms/DEFAULT .bucket/transforms/DEFAULT_TAIL .bucket/transforms/func/FOO .bucket/transforms/func/QUX!,
        grep { $expected{'fooqux'}{$_}{'blob'} } keys %{$expected{'fooqux'}}
    ]
);

# Check bucket for barqux1
blob_is( 'barqux1', 'NODELIST', "barqux1\n" );
blob_like( 'barqux1', 'REPO',    qr!^\QURL: svn+ssh://example.com/qwer\E$!m );
blob_like( 'barqux1', 'VERSION', qr/^\d+$/ );
blob_is( 'barqux1', '.bucket/transforms-index', '["DEFAULT","func/BAR","func/QUX","DEFAULT_TAIL"]' );
blobsha_is( 'barqux1', '.bucket/transforms/DEFAULT',      '05c23445ef27b1dfe3721899b24e91d7df6a1fdc' );
blobsha_is( 'barqux1', '.bucket/transforms/func/BAR',     '4f097857906bbe2c2b8a9f5bc19f01506b1ac906' );
blobsha_is( 'barqux1', '.bucket/transforms/func/QUX',     '03e9a760575a2eaaba907d3b4321871b1190a7d2' );
blobsha_is( 'barqux1', '.bucket/transforms/DEFAULT_TAIL', '1d8ff62ef10931b76611097844a52f9d0ea936b1' );
blob_is( 'barqux1', "$_", $_->{'blob'} ) for grep { $expected{'barqux'}{$_}{'blob'} } values %{ $expected{'barqux'} };
nodefiles_are(
    'barqux1',
    [
        sort qw!MANIFEST MANIFEST.asc NODELIST REPO VERSION!,
        qw! .bucket/transforms-index .bucket/transforms/DEFAULT .bucket/transforms/DEFAULT_TAIL .bucket/transforms/func/BAR .bucket/transforms/func/QUX!,
        grep { $expected{'barqux'}{$_}{'blob'} } keys %{$expected{'barqux'}}
    ]
);

# BINARY transform
blobsha_is( 'bin0', 'files/fake.png/MAIN', '8c8c0b4336192e56423048c7a7b604e722fe579e' );

# UNICODE transform
blobsha_is( 'u0', 'files/motd/MAIN', '82f4b733774c3fc73652d47824ceb7c7ad851c8a' );
blobsha_is( 'u0', 'files/homedir/MAIN', '391f4ca39ab7e343d9501c5d28486f61d5964f61' );

# INVALID transform
blob_is( 'invalid1', '.error', <<'EOT' );
TransformSet [t//DEFAULT@05c23445ef27b1dfe3721899b24e91d7df6a1fdct//DEFAULT_TAIL@1d8ff62ef10931b76611097844a52f9d0ea936b1t//func/INVALID@ee139c40f14fe0f73fa6ec416b951f7eeea01ccc] DOA: func/INVALID@ee139c40f14fe0f73fa6ec416b951f7eeea01ccc: rules section is not a key-to-list yaml map
EOT

# MODULE_BUNDLE transform
blob_is( 'mb0', 'files/passwd/linux', "root:x:0:0:System Administrator:/var/root:/bin/sh\n" );
