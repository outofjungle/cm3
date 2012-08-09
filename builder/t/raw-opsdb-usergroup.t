#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 6;
use Test::Differences;
use Test::Exception;
use Chisel::Builder::Raw::UserGroup;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

package FakecmdbClient;

{
    # the scope is to hide this from the rest of the program
    my @groups = (
        {   id      => 1,
            name    => 'uga',
            members => [qw/ john jill /],
            type    => 'ilist',
        },
        {   id      => 2,
            name    => 'ugb',
            members => [qw/ badguy /],
            type    => 'ilist',
        },
        {   id      => 3,
            name    => 'ugb',
            members => [],
            type    => 'cmdb',
        },
        {   id      => 4,
            name    => 'ugc',
            members => [qw/ bob /],
            type    => 'cmdb',
        },
        {   id      => 5,
            name    => 'ugc',
            members => [qw/ bob badguy /],
            type    => 'ilist',
        },
        {   id      => 6,
            name    => 'ugd',
            type    => 'cmdb',
            fake    => 1,
        },
        {   id      => 666,
            name    => 'goofy2',
            type    => 'cmdb',
        },
    );
    
    sub UserGroupsFind {
        my ( undef, %args ) = @_;

        die 'you should be using without_pagination' unless $args{'without_pagination'};
        my $arg = $args{'name'};

        if( $arg eq 'goofy' ) {
            # special test for cmdb returning 'goofy' results
            return ( { 'type' => 'cmdb', 'jacked' => 'up' } );
        } elsif( ! grep { $_->{name} eq $arg } @groups ) {
            # group not found
            die "No UserGroup(s) Found";
        } else {
            # normal successful test

            return
                map +{ id => $_->{id}, name => $_->{name}, type => $_->{type} },    # basically to remove 'members'
                grep { $_->{name} eq $arg } @groups;
        }
    }
    
    sub UserGroupMembers {
        my ( undef, %args ) = @_;

        my $arg = $args{'id'};
        
        if( $arg == 666 ) {
            # special test for cmdb returning 'goofy' results
            return map +{ username_goofy => $_ }, qw/ user1 user2 /;
        } elsif( my ($group) = grep { $_->{id} == $arg && ! $_->{fake} } @groups ) {
            # normal test
            if( @{$group->{members}} ) {
                return map +{ username => $_ }, @{$group->{members}};
            } else {
                # cmdb API returns this error message
                die "No members found";
            }
        } else {
            # group not found, or group's "fake" param was set
            die "user group id '$arg' does not exist\n";
        }
    }
}

package main;

# set up a relatively straightforward raw fs

my $raw_cmdb = Chisel::Builder::Raw::UserGroup->new( c => bless( { host => "x", user => "y" }, "FakecmdbClient" ) );

# try to read some groups out of it
is( $raw_cmdb->fetch( "uga" ), "jill\njohn\n" );
is( $raw_cmdb->fetch( "ugb" ), "" );
is( $raw_cmdb->fetch( "ugc" ), "bob\n" );

# try a failure
throws_ok { $raw_cmdb->fetch( "ugd" ) } qr/user group id '6' does not exist/;
throws_ok { $raw_cmdb->fetch( "goofy" ) } qr/UserGroups\.Find returned unusable groups for \[goofy\]/;
throws_ok { $raw_cmdb->fetch( "goofy2" ) } qr/cmdb gave us a usergroup without users/;
