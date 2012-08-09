#!/usr/local/bin/perl

# bucket-manifest.t -- mostly focuses on tests of manifest() and manifest_json(), has some incidental tests of add()

use warnings;
use strict;
use Digest::MD5 qw/md5_hex/;
use File::Temp qw/tempdir/;
use Test::More tests => 1;
use Test::Differences;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Bucket"); }

# todo

# ideas:
# - test that manifest() gives you something you can screw with and is NOT related to the bucket
