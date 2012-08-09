#!/usr/local/bin/perl

use warnings;
use strict;
use Digest::MD5 qw/md5_hex/;
use File::Temp qw/tempdir/;
use Test::More tests => 12;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Workspace"); }

# too many parameters should die
throws_ok { my $bucket = Chisel::Workspace->new( dir => "/tmp", badparam => 0 ); } qr/^Too many parameters/, "Workspace->new dies with unrecognized parameters";

can_ok( "Chisel::Workspace", "new" );
can_ok( "Chisel::Workspace", "host_bucket" );
can_ok( "Chisel::Workspace", "host_file" );
can_ok( "Chisel::Workspace", "nodemap" );
can_ok( "Chisel::Workspace", "cat_blob" );
can_ok( "Chisel::Workspace", "store_blob" );
can_ok( "Chisel::Workspace", "store_bucket" );
can_ok( "Chisel::Workspace", "write_host" );
can_ok( "Chisel::Workspace", "commit_mirror" );

my $tmp = tempdir( CLEANUP => 1 );
my $ws = Chisel::Workspace->new( dir => "$tmp" );
isa_ok($ws, "Chisel::Workspace", "Workspace object creation");
