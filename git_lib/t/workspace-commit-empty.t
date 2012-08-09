#!/usr/local/bin/perl

# try committing an empty nodemap
# make sure it works

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

my $ws = Chisel::Workspace->new( dir => wsinit() );

# this is the behavior we should see on a fresh repo:
eq_or_diff( $ws->nodemap, {} );
eq_or_diff( $ws->nodemap, {}, "nodemap is empty" );
