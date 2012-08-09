#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 1;
use Test::Differences;
use ChiselTest::Engine;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $engine     = ChiselTest::Engine->new;
my @transforms = $engine->new_checkout->transforms();
my $walrus     = $engine->new_walrus(
    tags       => [],
    transforms => \@transforms,
);

my %transforms_lookup = map { $_->name => $_ } @transforms;

# expected host -> transform map
my %exp_ht = (
    'bar1'       => [ @transforms_lookup{ sort qw(DEFAULT func/BAR host/bar1 DEFAULT_TAIL) } ],
    'bar2'       => [ @transforms_lookup{ sort qw(DEFAULT func/BAR DEFAULT_TAIL) } ],
    'bar3'       => [ @transforms_lookup{ sort qw(DEFAULT func/BAR DEFAULT_TAIL) } ],
    'barqux1'    => [ @transforms_lookup{ sort qw(DEFAULT func/BAR func/QUX DEFAULT_TAIL) } ],
    'barqux2'    => [ @transforms_lookup{ sort qw(DEFAULT func/BAR func/QUX DEFAULT_TAIL) } ],
    'foo1'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
    'foo2'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
    'foo3'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
    'foobar1'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR DEFAULT_TAIL) } ],
    'foobar2'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR DEFAULT_TAIL) } ],
    'foobarqux1' => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR func/QUX DEFAULT_TAIL) } ],
    'fooqux1'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/QUX DEFAULT_TAIL) } ],
    'qux1'       => [ @transforms_lookup{ sort qw(DEFAULT func/QUX DEFAULT_TAIL) } ],
    'qux2'       => [ @transforms_lookup{ sort qw(DEFAULT func/QUX DEFAULT_TAIL) } ],
    'qux3'       => [ @transforms_lookup{ sort qw(DEFAULT func/QUX DEFAULT_TAIL) } ],
);

my %got_ht = map { $_ => [ sort { $a->name cmp $b->name} $walrus->host_transforms( host => $_ ) ] } $walrus->range;

eq_or_diff( \%got_ht, \%exp_ht, "bucket generation" );
