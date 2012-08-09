#!/usr/bin/perl

# generator-sort-transforms.t -- basic transform sorting

use warnings;
use strict;
use Test::More tests => 28;
use Test::Differences;
use Test::Exception;
use File::Temp qw/tempdir/;
use Chisel::Transform;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

# make some transforms with interesting ordering
my @transforms = (
    Chisel::Transform->new( name => 'DEFAULT',            yaml => YAML::XS::Dump( {}, {} ) ),
    Chisel::Transform->new( name => 'DEFAULT_TAIL',       yaml => YAML::XS::Dump( {}, {} ) ),
    Chisel::Transform->new( name => 'group_role/a',     yaml => YAML::XS::Dump( {}, {} ) ),
    Chisel::Transform->new( name => 'group_role/A.x',   yaml => YAML::XS::Dump( {}, {} ) ),
    Chisel::Transform->new( name => 'group_role/a.x.y', yaml => YAML::XS::Dump( {}, {} ) ),
    Chisel::Transform->new( name => 'group_role/b',     yaml => YAML::XS::Dump( {}, { follows => ['group_role/c'] } ) ),
    Chisel::Transform->new( name => 'group_role/c',     yaml => YAML::XS::Dump( {}, {} ) ),
    Chisel::Transform->new( name => 'group_role/cx',    yaml => YAML::XS::Dump( {}, {} ) ),
    Chisel::Transform->new( name => 'group_role/d',     yaml => YAML::XS::Dump( {}, { follows => ['group_role/a'] } ) ),
    Chisel::Transform->new( name => 'wtf/c',              yaml => YAML::XS::Dump( {}, {} ) ),
    Chisel::Transform->new( name => 'func/FOO',           yaml => YAML::XS::Dump( {}, {} ) ),
    Chisel::Transform->new( name => 'func/BAR',           yaml => YAML::XS::Dump( {}, { follows => ['func/F?o'] } ) ),
    Chisel::Transform->new( name => 'func/QUX',           yaml => YAML::XS::Dump( {}, { follows => ['fuNC/*'] } ) ),
    Chisel::Transform->new( name => 'host/bar1',          yaml => YAML::XS::Dump( {}, {} ) ),
    Chisel::Transform->new( name => 'host/not.a.host',    yaml => YAML::XS::Dump( {}, {} ) ),
    Chisel::Transform->new(
        name => 'func/QUX-conflict',
        yaml => YAML::XS::Dump( {}, { follows => [ 'junk/???', 'func/QUX' ] } )
    ),
    Chisel::Transform->new(
        name => 'func/bar1-conflict',
        yaml => YAML::XS::Dump( {}, { follows => ['host/bar1'] } )
    ),

);

my %transforms_lookup = map { $_->name => $_ } @transforms;

# transform ordering is done in two passes:
# 1. Enforced ordering of major category, like "host", "func", "group_role", etc.
# 2. User-defined ordering within each major category from "follows" directives

# try an empty list -- should work
eq_or_diff( [ Chisel::Transform->order() ],
    [], "empty list sorts to empty list" );

# try a bunch of things that should work
order_is( [ @transforms_lookup{"DEFAULT", "DEFAULT_TAIL"} ] );
order_is( [ @transforms_lookup{"group_role/a", "group_role/A.x", "group_role/a.x.y", "group_role/c"} ] );
order_is( [ @transforms_lookup{"group_role/c", "group_role/b", "group_role/d"} ] );
order_is( [ @transforms_lookup{"group_role/c", "group_role/b", "group_role/cx", "group_role/d"} ] );
order_is( [ @transforms_lookup{"group_role/a", "group_role/c", "group_role/d"} ] );
order_is( [ @transforms_lookup{"func/FOO", "host/bar1"} ] );
order_is( [ @transforms_lookup{"func/QUX", "host/bar1"} ] );
order_is( [ @transforms_lookup{"func/FOO", "host/not.a.host"} ] );
order_is( [ @transforms_lookup{"func/FOO", "func/BAR", "func/QUX", "host/bar1"} ] );
order_is( [ @transforms_lookup{"func/FOO", "func/BAR", "func/QUX", "host/not.a.host"} ] );
order_is( [ @transforms_lookup{"DEFAULT", "func/FOO", "func/BAR", "func/QUX", "host/bar1", "DEFAULT_TAIL"} ] );
order_is( [ @transforms_lookup{"DEFAULT", "func/FOO", "func/BAR", "func/QUX", "host/not.a.host", "DEFAULT_TAIL"} ] );
order_is( [ @transforms_lookup{"func/FOO", "func/BAR", "func/QUX"} ] );
order_is( [ @transforms_lookup{"func/FOO", "group_role/a", "group_role/A.x", "group_role/a.x.y", "host/bar1"} ] );
order_is( [ @transforms_lookup{"func/FOO", "func/BAR"} ] );
order_is( [ @transforms_lookup{"func/FOO", "func/QUX"} ] );
order_is( [ @transforms_lookup{"func/BAR", "func/QUX"} ] );
order_is( [ @transforms_lookup{"func/FOO"} ] );
order_is( [ @transforms_lookup{"func/BAR"} ] );
order_is( [ @transforms_lookup{"func/QUX"} ] );
order_is( [ @transforms_lookup{"DEFAULT", "func/QUX", "DEFAULT_TAIL"} ] );

# try two transforms with the same name
# this isn't supported by a bunch of other parts of the program, and it might be a bad idea, but eh
my $t_foo1 =
  Chisel::Transform->new( name => 'group_role/foo', yaml => YAML::XS::Dump( { xxx => ["append 1"] }, { follows => [ 'group_role/foo' ] } ) );
my $t_foo2 =
  Chisel::Transform->new( name => 'group_role/foo', yaml => YAML::XS::Dump( { xxx => ["append 2"] }, {} ) );

order_is( [$t_foo2, $t_foo1] );

# try non-object
cant_order( [ 'DEFAULT' ], qr/Can't locate object method "name" via package "DEFAULT"/ );

# try undef plus a real one
cant_order( [ $transforms_lookup{"func/FOO"}, 'DEFAULT' ], qr/Can't locate object method "name" via package "DEFAULT"/ );

# try incompatible transforms (circular dependencies)
cant_order( [ @transforms_lookup{"func/bar1-conflict", "host/bar1"} ], qr{Unable to resolve dependencies between transforms: (func/bar1-conflict, host/bar1|host/bar1, func/bar1-conflict)} );

# try incompatible transforms plus some that work
my $conflict_re = join '|', map { join ", ", @$_ } permutations( qw{host/bar1 func/QUX func/QUX-conflict} );
cant_order( [ @transforms_lookup{"func/FOO", "func/BAR", "func/QUX", "host/bar1", "func/QUX-conflict"} ], qr{Unable to resolve dependencies between transforms: ($conflict_re)} );

# try a bad kind of transform
cant_order( [ @transforms_lookup{"wtf/c"} ], qr/transform type 'wtf' not recognized/ );

sub cant_order {
    my ( $sorted, $why, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    
    $message ||= "transforms cannot be sorted properly: @$sorted";
    
    # reorganize them into as many unsorted lists as possible
    my @unsorteds = permutations( @$sorted );
    
    # try sorting them all
    subtest $message => sub {
        plan tests => scalar @unsorteds;
        foreach my $unsorted (@unsorteds) {
            throws_ok { Chisel::Transform->order(@$unsorted); 1; } $why, "cannot sort @$unsorted";
        }
    };
}

sub order_is {
    my ( $sorted, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    
    $message ||= "transforms can be sorted properly: @$sorted";
    
    # reorganize them into as many unsorted lists as possible
    my @unsorteds = permutations( @$sorted );

    # try sorting them all, make sure they end up in the right order
    subtest $message => sub {
        plan tests => scalar @unsorteds;
        foreach my $unsorted (@unsorteds) {
            eq_or_diff( [ map { $_->id } Chisel::Transform->order(@$unsorted) ],
                [ map { $_->id } @$sorted ], "can sort @$unsorted into @$sorted" );
        }
    };
}

sub permutations {
    my ( @list ) = @_;
    
    if( @list == 0 ) {
        return ();
    } elsif( @list == 1 ) {
        return ( [ $list[0] ] );
    } else {
        my @perms;

        # for each item, concatenate it to permutations of the rest
        
        for( my $i = 0; $i < @list; $i++ ) {
            # remove item $i
            my $li = splice @list, $i, 1;
            
            # concatenate it to permutations of the rest
            push @perms, map { [ $li, @$_ ] } permutations(@list);
            
            # reattach item $i
            splice @list, $i, 0, $li;
        }

        return @perms;
    }
}
