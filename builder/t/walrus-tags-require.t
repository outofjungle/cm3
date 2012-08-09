#!/usr/bin/perl

# walrus-tags-require.t -- like walrus-tags-global.t, but set require_tag => 1

use warnings;
use strict;
use Test::More tests => 1;
use Test::Differences;
use ChiselTest::Engine;
use ChiselTest::FakeFunc;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $engine            = ChiselTest::Engine->new;
my $checkout          = $engine->new_checkout( tagdir => "t/files/configs.1/tags.2", );
my @transforms        = $checkout->transforms;
my %transforms_lookup = map { $_->name => $_ } @transforms;

my $walrus = $engine->new_walrus(
    tags        => [ $checkout->tags ],
    transforms  => \@transforms,
    require_tag => 1,
);

my %exp_ht = (
    'bar1'       => [ @transforms_lookup{ sort qw(DEFAULT func/BAR host/bar1 DEFAULT_TAIL) } ],
    'bar2'       => [],
    'bar3'       => [],
    'barqux1'    => [ @transforms_lookup{ sort qw(DEFAULT func/BAR func/QUX DEFAULT_TAIL) } ],
    'barqux2'    => [ @transforms_lookup{ sort qw(DEFAULT func/BAR func/QUX DEFAULT_TAIL) } ],
    'foo1'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
    'foo2'       => [],
    'foo3'       => [],
    'foobar1'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR DEFAULT_TAIL) } ],
    'foobar2'    => [],
    'foobarqux1' => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR func/QUX DEFAULT_TAIL) } ],
    'fooqux1'    => [ @transforms_lookup{ sort qw(DEFAULT func/QUX DEFAULT_TAIL) } ],
    'qux1'       => [],
    'qux2'       => [],
    'qux3'       => [],
);

my %got_ht = map {
    $_ => [ sort { $a->name cmp $b->name } $walrus->host_transforms( host => $_ ) ]
} $walrus->range;

eq_or_diff( \%got_ht, \%exp_ht, "bucket generation with tags + GLOBAL tag + require_tag=1" );
