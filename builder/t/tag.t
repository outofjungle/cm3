#!/usr/bin/perl

# tag.t -- ensure that tag objects work as expected

use warnings;
use strict;
use Test::More tests => 41;
use Test::Differences;
use Test::Exception;
use ChiselTest::FakeFunc;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Tag"); }

my $taga_yaml  = scalar qx[cat t/files/configs.1/tags.1/taga];
my $tagb_yaml  = scalar qx[cat \Qt/files/configs.1/tags.1/TAG B\E];
my $notag_yaml = scalar qx[cat t/files/configs.1/tags/notag];

# taga checks
do {
    my $taga  = Chisel::Tag->new( name => 'tag/a',  yaml => $taga_yaml );

    # all nodes can be in DEFAULT, DEFAULT_TAIL, host/hostname (case insensitive)
    ok( $taga->match( NamedThing->new( "DEFAULT" ) ) );
    ok( $taga->match( NamedThing->new( "DEFAULT_TAIL" ) ) );
    ok( $taga->match( NamedThing->new( "host/BAR1" ) ) );
    ok( $taga->match( NamedThing->new( "HOST/BAR1" ) ) );
    
    # taga contains only "func/FOO" and "func/BAR"
    ok( $taga->match( NamedThing->new( "func/FOO" ) ) );
    ok( $taga->match( NamedThing->new( "func/BAR" ) ) );
    ok( !$taga->match( NamedThing->new( "func/QUX" ) ) );
    
    # try different cases
    ok( $taga->match( NamedThing->new( "FUNC/foo" ) ) );
    ok( $taga->match( NamedThing->new( "fuNC/bAr" ) ) );
    
    # try adding junk, it shouldn't match
    ok( !$taga->match( NamedThing->new( "func/BARX" ) ) );
    ok( !$taga->match( NamedThing->new( "func/BAR " ) ) );
    ok( !$taga->match( NamedThing->new( "Xfunc/BAR" ) ) );
    ok( !$taga->match( NamedThing->new( " func/BAR" ) ) );
    ok( !$taga->match( NamedThing->new( "func/FOOfunc/BAR" ) ) );
    
    # try list form
    eq_or_diff(
        [ $taga->match( map { NamedThing->new($_) } qw(func/FOO func/BAR func/QUX FUNC/foo func/BARX) ) ],
        [ map { NamedThing->new($_) } qw(func/FOO func/BAR FUNC/foo)],
        "Tag->match in list form"
    );
};

# tag b checks
do {
    my $tagb  = Chisel::Tag->new( name => 'TAG/B B',  yaml => $tagb_yaml );

    # all nodes can be in DEFAULT, DEFAULT_TAIL, host/hostname (case insensitive)
    ok( $tagb->match( NamedThing->new( "DEFAULT" ) ) );
    ok( $tagb->match( NamedThing->new( "DEFAULT_TAIL" ) ) );
    ok( $tagb->match( NamedThing->new( "host/BAR1" ) ) );
    ok( $tagb->match( NamedThing->new( "HOST/BAR1" ) ) );
    
    # tagb contains only "*/BAR" and "*/QUX"
    ok( !$tagb->match( NamedThing->new( "func/FOO" ) ) );
    ok( $tagb->match( NamedThing->new( "func/BAR" ) ) );
    ok( $tagb->match( NamedThing->new( "func/QUX" ) ) );
    
    # try different cases
    ok( $tagb->match( NamedThing->new( "FUNC/bAr" ) ) );
    ok( $tagb->match( NamedThing->new( "fuNC/qux" ) ) );
    
    # try a different prefixes
    ok( $tagb->match( NamedThing->new( "blah/bAr" ) ) );
    
    # try NO prefix
    ok( !$tagb->match( NamedThing->new( "bAr" ) ) );
    
    # try multiple slashes
    ok( !$tagb->match( NamedThing->new( "blah/func/BAR" ) ) );
    
    # try adding junk at the end, it shouldn't match
    ok( !$tagb->match( NamedThing->new( "func/BARX" ) ) );
};

# notag checks
do {
    my $notag = Chisel::Tag->new( name => 'tag/no', yaml => $notag_yaml );

    # all nodes can be in DEFAULT, DEFAULT_TAIL, host/hostname (case insensitive)
    ok( $notag->match( NamedThing->new( "DEFAULT" ) ) );
    ok( $notag->match( NamedThing->new( "DEFAULT_TAIL" ) ) );
    ok( $notag->match( NamedThing->new( "host/BAR1" ) ) );
    
    # notag contains NOTHING!
    ok( !$notag->match( NamedThing->new( "func/FOO" ) ) );
    ok( !$notag->match( NamedThing->new( "func/BAR" ) ) );
    ok( !$notag->match( NamedThing->new( "func/QUX" ) ) );
};

# checks on a bad tag
do {
    my $badtag = Chisel::Tag->new( name => 'tag/bad', yaml => "- xxx\nrofl\n" );
    
    throws_ok { $badtag->match( NamedThing->new( "DEFAULT" ) ) } qr/YAML::XS::Load Error/, "Tag->match detects bad YAML";
    throws_ok { $badtag->match( NamedThing->new( "DEFAULT_TAIL" ) ) } qr/YAML::XS::Load Error/, "Tag->match detects bad YAML";
    throws_ok { $badtag->match( NamedThing->new( "host/BAR1" ) ) } qr/YAML::XS::Load Error/, "Tag->match detects bad YAML";
};

# check on bad tag constructor usage
do {
    throws_ok { my $errtag = Chisel::Tag->new; } qr/tag 'name' not given/, "constructor complains when 'name' is not given";
    throws_ok { my $errtag = Chisel::Tag->new( name => 'tag/xxx', yaml => '', blah => '' ); } qr/Too many parameters/, "constructor complains when too many args are given";
    throws_ok { my $errtag = Chisel::Tag->new( name => 'xxx', yaml => '' ); } qr/tag 'name' is not well-formatted/, "constructor complains when tag name is bad";
};

package NamedThing;

sub new {
    my ( $class, $name ) = @_;
    $name = "$name";
    bless \$name, $class;
}

sub name {
    my $self = shift;
    return $$self;
}
