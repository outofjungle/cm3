#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 3;
use Test::Differences;
use ChiselTest::Engine;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $engine            = ChiselTest::Engine->new;
my @transforms        = $engine->new_checkout->transforms();
my %transforms_lookup = map { $_->name => $_ } @transforms;

# check require_group that has a transform
do {
    my $walrus = $engine->new_walrus(
        tags          => [],
        transforms    => \@transforms,
        require_group => ['func/FOO'],
    );

    # expected host -> transform map
    my %exp_ht = (
        'bar1'       => [],
        'bar2'       => [],
        'bar3'       => [],
        'barqux1'    => [],
        'barqux2'    => [],
        'foo1'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
        'foo2'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
        'foo3'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
        'foobar1'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR DEFAULT_TAIL) } ],
        'foobar2'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR DEFAULT_TAIL) } ],
        'foobarqux1' => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR func/QUX DEFAULT_TAIL) } ],
        'fooqux1'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/QUX DEFAULT_TAIL) } ],
        'qux1'       => [],
        'qux2'       => [],
        'qux3'       => [],
    );

    my %got_ht = map {
        $_ => [ sort { $a->name cmp $b->name } $walrus->host_transforms( host => $_ ) ]
    } $walrus->range;

    eq_or_diff( \%got_ht, \%exp_ht, "bucket generation with a require_group that has a transform" );
};

# check require_group that does NOT have a transform
do {
    my $walrus = $engine->new_walrus(
        tags          => [],
        transforms    => \@transforms,
        require_group => ['func/SOME'],
    );

    # expected buckets
    my %exp_ht = (
        'bar1'       => [ @transforms_lookup{ sort qw(DEFAULT func/BAR host/bar1 DEFAULT_TAIL) } ],
        'bar2'       => [],
        'bar3'       => [],
        'barqux1'    => [ @transforms_lookup{ sort qw(DEFAULT func/BAR func/QUX DEFAULT_TAIL) } ],
        'barqux2'    => [],
        'foo1'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
        'foo2'       => [],
        'foo3'       => [],
        'foobar1'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR DEFAULT_TAIL) } ],
        'foobar2'    => [],
        'foobarqux1' => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR func/QUX DEFAULT_TAIL) } ],
        'fooqux1'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/QUX DEFAULT_TAIL) } ],
        'qux1'       => [ @transforms_lookup{ sort qw(DEFAULT func/QUX DEFAULT_TAIL) } ],
        'qux2'       => [],
        'qux3'       => [],
    );

    my %got_ht = map {
        $_ => [ sort { $a->name cmp $b->name } $walrus->host_transforms( host => $_ ) ]
    } $walrus->range;

    eq_or_diff( \%got_ht, \%exp_ht, "bucket generation with a require_group that does not have a transform" );
};

# check require_group with two groups (should be OK if either one is present)
do {
    my $walrus = $engine->new_walrus(
        tags          => [],
        transforms    => \@transforms,
        require_group => ['func/FOO', 'func/SOME'],
    );

    # expected buckets
    my %exp_ht = (
        'bar1'       => [ @transforms_lookup{ sort qw(DEFAULT func/BAR host/bar1 DEFAULT_TAIL) } ],
        'bar2'       => [],
        'bar3'       => [],
        'barqux1'    => [ @transforms_lookup{ sort qw(DEFAULT func/BAR func/QUX DEFAULT_TAIL) } ],
        'barqux2'    => [],
        'foo1'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
        'foo2'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
        'foo3'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
        'foobar1'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR DEFAULT_TAIL) } ],
        'foobar2'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR DEFAULT_TAIL) } ],
        'foobarqux1' => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR func/QUX DEFAULT_TAIL) } ],
        'fooqux1'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/QUX DEFAULT_TAIL) } ],
        'qux1'       => [ @transforms_lookup{ sort qw(DEFAULT func/QUX DEFAULT_TAIL) } ],
        'qux2'       => [],
        'qux3'       => [],
    );

    my %got_ht = map {
        $_ => [ sort { $a->name cmp $b->name } $walrus->host_transforms( host => $_ ) ]
    } $walrus->range;

    eq_or_diff( \%got_ht, \%exp_ht, "bucket generation with a require_group that does not have a transform" );
};
