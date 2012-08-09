#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 9;
use Test::Differences;
use Test::Exception;
use Chisel::Builder::Raw::HostList;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

# make a fake roles client
my $rocl = bless( \do { my $anon = '' }, "FakeRolesClient" );

# hostlist from a tag
do {
    my $hl = Chisel::Builder::Raw::HostList->new(
        range_tag    => "tag.a",
        roles_client => $rocl,
    );

    is( $hl->fetch( "dump" ), "bar\nbaz\nfoo\n", "host list from tag.a" );
};

# hostlist from an empty tag
do {
    my $hl = Chisel::Builder::Raw::HostList->new(
        range_tag    => "tag.b",
        roles_client => $rocl,
    );

    is( $hl->fetch( "dump" ), "", "host list from tag.b" );
};

# hostlist from a tag that references nonexistent roles
do {
    my $hl = Chisel::Builder::Raw::HostList->new(
        range_tag    => "tag.d",
        roles_client => $rocl,
    );

    throws_ok { $hl->fetch( "dump" ) } qr/role 'role.nonexistent' does not exist/;
};

# construction errors
throws_ok { Chisel::Builder::Raw::HostList->new( roles_client => $rocl ) } qr/Please pass in a roles tag as 'range_tag'/;

# validation tests
do {
    my $hl = Chisel::Builder::Raw::HostList->new(
        range_tag    => "xxx",
        maxchange    => 2,
        roles_client => $rocl,
    );

    throws_ok { $hl->validate( "dump", undef,             "foo\n" ) } qr/dump: blocked removal/;
    throws_ok { $hl->validate( "dump", "foo\nbar\nbaz\n", "foo1\n" ) } qr/too many changes \(4 > 2\)/;
    throws_ok { $hl->validate( "dump", "foo1\n",          "foo\nbar\nbaz\n" ) } qr/too many changes \(4 > 2\)/;

    is( $hl->validate( "dump", "foo\nbar\nbaz\n", "foo\n" ),           1 );
    is( $hl->validate( "dump", "foo\n",           "foo\nbar\nbaz\n" ), 1 );
};

package FakeRolesClient;

sub tag {
    my ( $self, $arg, $want ) = @_;

    my %tags = (
        'tag.a' => [qw / role.a role.b /],
        'tag.b' => [],
        'tag.c' => [qw / role.c /],
        'tag.d' => [qw / role.nonexistent /],
    );

    die 'you should be asking for "roles"' unless $want eq 'roles';

    if( exists $tags{$arg} ) {
        return { roles => [ map { $self->role($_) } @{ $tags{$arg} } ] };
    } else {
        die "tag '$arg' does not exist\n";
    }
}

sub role {
    my ( $self, $arg, $want ) = @_;

    my %roles = (
        'role.a' => { ns => 'role', name => 'a', id => 1, mtime => 1, members => [qw/ FOo bar /] },
        'role.b' => { ns => 'role', name => 'b', id => 2, mtime => 1, members => [qw/ FoO baz /] },
        'role.c' => { ns => 'role', name => 'c', id => 3, mtime => 1, members => [qw/ qux /] },
    );

    die 'you should be asking for "members" or nothing'
      if defined $want && $want ne 'members';

    if( exists $roles{$arg} ) {
        return $roles{$arg};
    } else {
        die "role '$arg' does not exist\n";
    }
}
