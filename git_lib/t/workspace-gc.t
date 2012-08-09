#!/usr/local/bin/perl

use warnings;
use strict;
use Digest::MD5 qw/md5_hex/;
use File::Temp qw/tempdir/;
use Test::More tests => 7;
use Test::Differences;
use Test::Exception;
use Test::Workspace qw/:all/;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $dir = wsinit();

# make an initial commit
my $ws = Chisel::Workspace->new( dir => $dir );

my %nodemap = %{ nodemap1() };
$ws->store_blob( $_ )   for blob();
$ws->store_bucket( $_ ) for values %nodemap;
$ws->write_host( $_, $nodemap{$_} ) for keys %nodemap;

# gc should not change anything
eq_or_diff( [ $ws->gc ], [], "gc on first commit" );

# remove all hosts on bucket1
my $delbucket = $nodemap{'hd'};
$nodemap{'hc'} = undef;
$nodemap{'hd'} = undef;
$ws->write_host( $_, $nodemap{$_} ) for keys %nodemap;

# gc should remove the blob for "" and the deleted bucket (other files overlap with the first bucket)
eq_or_diff( [ sort $ws->gc( dryrun => 1 ) ], [ sort ( blob( "" ), $delbucket->tree ) ], "gc on second commit" );

# test keep_files / keep_buckets
eq_or_diff(
    [ sort $ws->gc( dryrun => 1, keep_files => [ blob( "" ) ] ) ],
    [ sort ( $delbucket->tree ) ],
    "gc keep_files('')"
);

eq_or_diff(
    [ sort $ws->gc( dryrun => 1, keep_files => [ blob( "foo bar baz\n" ) ] ) ],
    [ sort ( blob( "" ), $delbucket->tree ) ],
    "gc keep_files(foo bar baz)"
);

eq_or_diff(
    [ sort $ws->gc( dryrun => 1, keep_files => [ blob( "foo bar baz\n" ), blob(""), blob( "foo bar baz\n" ) ] ) ],
    [ sort ( $delbucket->tree ) ],
    "gc keep_files(foo bar baz, '', foo bar baz)"
);

eq_or_diff(
    [ sort $ws->gc( dryrun => 1, keep_buckets => [ blob( "" ) ] ) ],
    [ sort ( blob( "" ), $delbucket->tree ) ],
    "gc keep_buckets('')"
);

eq_or_diff(
    [ sort $ws->gc( dryrun => 1, keep_buckets => [ $delbucket->tree ] ) ],
    [ sort ( blob( "" ) ) ],
    "gc keep_buckets(delbucket->tree)"
);
