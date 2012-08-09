#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 6;
use Test::Differences;
use Test::Exception;
use Chisel::Builder::Raw::Roles;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

package FakeRolesClient;

sub role {
    my ( undef, $arg, $thingy ) = @_;
    
    my %roles = (
        'role.a' => [ qw/ foo bar / ],
        'role.b' => [],
        'role.c' => [ qw/ qux / ],
    );
    
    die 'you should be asking for "members"' unless $thingy eq 'members';
    
    if( $arg eq 'goofy' ) {
        # special test for roles returning 'goofy' results
        return {};
    } elsif( exists $roles{$arg} ) {
        # normal successful test
        return { members => [ @{$roles{$arg}} ] };
    } else {
        die "role '$arg' does not exist\n";
    }
}

package main;

# set up a relatively straightforward raw fs

my $fsobj = Chisel::Builder::Raw::Roles->new( c => bless( \do{my $anon = ''}, "FakeRolesClient" ) );

# try to read some roles out of it
is( $fsobj->fetch( "role.a" ), "bar\nfoo\n" );
is( $fsobj->fetch( "role.b" ), "" );
is( $fsobj->fetch( "role.c" ), "qux\n" );

# try a failure
ok( ! defined $fsobj->fetch( "role.d" ) );
like( $fsobj->last_nonfatal_error, qr/role 'role.d' does not exist/ );
throws_ok { $fsobj->fetch( "goofy" ) } qr/Can't use an undefined value as an ARRAY reference/;
