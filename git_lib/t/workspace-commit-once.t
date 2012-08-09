#!/usr/local/bin/perl

use warnings;
use strict;
use Digest::MD5 qw/md5_hex/;
use File::Temp qw/tempdir/;
use Test::More tests => 17;
use Test::Differences;
use Test::Exception;
use Test::Workspace qw/:all/;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $ws        = Chisel::Workspace->new( dir => wsinit() );
my $ws_mirror = Chisel::Workspace->new( dir => $ws->{'dir'} );

# this is the behavior we should see on a fresh repo:
eq_or_diff( $ws->nodemap,        {} );
eq_or_diff( $ws_mirror->nodemap, {} );

# store blobs and buckets
my %nodemap = %{nodemap1()};
$ws->store_blob( $_ )   for blob();
$ws->store_bucket( $_ ) for values %nodemap;

# let's make a commit
$ws->write_host( $_, $nodemap{$_} ) for keys %nodemap;

# read from nodemap
my $ws_nodemap = $ws->nodemap;
$_->tree for values %$ws_nodemap; # we need to run this for eq_or_diff to be happy
eq_or_diff( $ws_nodemap, \%nodemap, "nodemap matches the one we committed" );
eq_or_diff( $ws_mirror->nodemap, \%nodemap, "nodemap-mirror matches the one we committed (1)" );

# make sure we can read the nodemap with a different workspace object
my $ws2 = Chisel::Workspace->new( dir => $ws->{'dir'} );
my $ws2_nodemap = $ws2->nodemap;
$_->tree for values %$ws2_nodemap; # we need to run this for eq_or_diff to be happy
eq_or_diff( $ws2_nodemap, \%nodemap, "nodemap matches the one we committed, even read from a different object" );
eq_or_diff( $ws_mirror->nodemap, \%nodemap, "nodemap-mirror matches the one we committed (2)" );

# try a no_object nodemap
my $ws4 = Chisel::Workspace->new( dir => $ws->{'dir'} );
my $no_object_nodemap = $ws4->nodemap( no_object => 1 );
eq_or_diff(
    $no_object_nodemap,
    { map { $_ => $nodemap{$_}->tree } keys %nodemap },
    "nodemap( no_object => 1 ) matches the one we committed"
);

# host_bucket
is( $ws->host_bucket( "ha" )->tree, "780c61045ea728c40793ff8891ba76f442a41ec2", "host_bucket(ha)" );
is( $ws->host_bucket( "hx" ), undef, "host_bucket(hx)" );

# host_bucketid
is( $ws->host_bucketid( "ha" ), "780c61045ea728c40793ff8891ba76f442a41ec2", "host_bucketid(ha)" );
is( $ws->host_bucket( "hx" ), undef, "host_bucketid(hx)" );

# host_file
is( $ws->host_file( "ha", "files/one/two" ),    blob( "hello world\n" ), "host_file(ha, files/one/two)" );
is( $ws->host_file( "hc", "files/one/two" ),    blob( "foo bar baz\n" ), "host_file(hc, files/one/two)" );
is( $ws->host_file( "ha", "files/one/nonono" ), undef,                   "host_file(ha, files/one/nonono)" );
is( $ws->host_file( "hx", "files/one/two" ),    undef,                   "host_file(hx, files/one/two)" );

# bucket
is(
    $ws->bucket( "780c61045ea728c40793ff8891ba76f442a41ec2" )->tree,
    "780c61045ea728c40793ff8891ba76f442a41ec2",
    "host_bucket(780c61045ea728c40793ff8891ba76f442a41ec2)"
);
is( $ws->bucket( "780c61045ea728c40793ff8891ba76f442a41ec3" ),
    undef, "host_bucket(780c61045ea728c40793ff8891ba76f442a41ec2)" );
