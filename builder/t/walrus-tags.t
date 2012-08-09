#!/usr/bin/perl

# walrus-tags.t -- ensure that tag files work as expected (this test is without GLOBAL and without require_tag)

use warnings;
use strict;
use Test::More tests => 11;
use Test::Differences;
use ChiselTest::Engine;
use ChiselTest::FakeFunc;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $engine            = ChiselTest::Engine->new;
my $checkout          = $engine->new_checkout( tagdir => "t/files/configs.1/tags.1", );
my @transforms        = $checkout->transforms;
my %transforms_lookup = map { $_->name => $_ } @transforms;

my $walrus = $engine->new_walrus(
    tags       => [ $checkout->tags ],
    transforms => \@transforms,
);

# check master tag list
eq_or_diff( [ sort map { "$_" } $walrus->tags ], [ "cmdb_property/TAG B", "cmdb_property/taga" ] );

# check tags for various nodes
eq_or_diff( [ sort map { "$_" } $walrus->host_tags( host => "foobar1" ) ],              ["cmdb_property/taga"],                           "tag list for foobar1" );
eq_or_diff( [ sort map { "$_" } $walrus->host_tags( host => "bar1" ) ],                 ["cmdb_property/taga"],                           "tag list for bar1" );
eq_or_diff( [ sort map { "$_" } $walrus->host_tags( host => "bar2" ) ],                 [],                                                "tag list for bar2" );
eq_or_diff( [ sort map { "$_" } $walrus->host_tags( host => "foo1" ) ],                 ["cmdb_property/taga"],                           "tag list for foo1" );
eq_or_diff( [ sort map { "$_" } $walrus->host_tags( host => "barqux1" ) ],              ["cmdb_property/taga"],                           "tag list for barqux1" );
eq_or_diff( [ sort map { "$_" } $walrus->host_tags( host => "barqux2" ) ],              [ "cmdb_property/TAG B", "cmdb_property/taga" ], "tag list for barqux2" );
eq_or_diff( [ sort map { "$_" } $walrus->host_tags( host => "foobarqux1" ) ],           ["cmdb_property/taga"],                           "tag list for foobarqux1" );
eq_or_diff( [ sort map { "$_" } $walrus->host_tags( host => "fooqux1" ) ],              ["cmdb_property/TAG B"],                          "tag list for fooqux1" );
eq_or_diff( [ sort map { "$_" } $walrus->host_tags( host => "fakenodedoesnotexist" ) ], [],                                                "tag list for fakenodedoesnotexist" );

# check buckets
my %exp_ht = (
    'bar1'       => [ @transforms_lookup{ sort qw(DEFAULT func/BAR host/bar1 DEFAULT_TAIL) } ],
    'bar2'       => [ @transforms_lookup{ sort qw(DEFAULT func/BAR DEFAULT_TAIL) } ],
    'bar3'       => [ @transforms_lookup{ sort qw(DEFAULT func/BAR DEFAULT_TAIL) } ],
    'barqux1'    => [ @transforms_lookup{ sort qw(DEFAULT func/BAR DEFAULT_TAIL) } ],
    'barqux2'    => [ @transforms_lookup{ sort qw(DEFAULT func/BAR func/QUX DEFAULT_TAIL) } ],
    'foo1'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
    'foo2'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
    'foo3'       => [ @transforms_lookup{ sort qw(DEFAULT func/FOO DEFAULT_TAIL) } ],
    'foobar1'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR DEFAULT_TAIL) } ],
    'foobar2'    => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR DEFAULT_TAIL) } ],
    'foobarqux1' => [ @transforms_lookup{ sort qw(DEFAULT func/FOO func/BAR DEFAULT_TAIL) } ],
    'fooqux1'    => [ @transforms_lookup{ sort qw(DEFAULT func/QUX DEFAULT_TAIL) } ],
    'qux1'       => [ @transforms_lookup{ sort qw(DEFAULT func/QUX DEFAULT_TAIL) } ],
    'qux2'       => [ @transforms_lookup{ sort qw(DEFAULT func/QUX DEFAULT_TAIL) } ],
    'qux3'       => [ @transforms_lookup{ sort qw(DEFAULT func/QUX DEFAULT_TAIL) } ],
);

my %got_ht = map {
    $_ => [ sort { $a->name cmp $b->name } $walrus->host_transforms( host => $_ ) ]
} $walrus->range;

eq_or_diff( \%got_ht, \%exp_ht, "bucket generation with tags" );
