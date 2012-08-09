#!/usr/local/bin/perl

use warnings;
use strict;
use Digest::MD5 qw/md5_hex/;
use File::Temp qw/tempdir/;
use Test::More tests => 2;
use Test::Differences;
use Test::Exception;
use Test::Workspace qw/:all/;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $dir = wsinit();

# make an initial commit
do {
    my %nodemap = %{ nodemap1() };
    my $ws = Chisel::Workspace->new( dir => $dir );

    $ws->store_blob( $_ )   for blob();
    $ws->store_bucket( $_ ) for values %nodemap;
    $ws->write_host( $_, $nodemap{$_} ) for keys %nodemap;
};

# committing a different thing should do something
do {
    my $ws = Chisel::Workspace->new( dir => $dir );
    my $nodemap;

    # before the new commit, nodemap should still return the old thing
    $nodemap = $ws->nodemap;
    $_->tree for values %$nodemap;
    eq_or_diff( $nodemap, nodemap1(), "nodemap returns the old hash before new commit" );

    # make the new commit
    my $nodemap2 = nodemap2();
    $ws->write_host( $_, undef ) for keys %$nodemap;
    $ws->write_host( $_, $nodemap2->{$_} ) for keys %$nodemap2;

    # test it
    $nodemap = $ws->nodemap;
    $_->tree for values %$nodemap;
    eq_or_diff( $nodemap, nodemap2(), "nodemap matches the newly committed hash" );
};
