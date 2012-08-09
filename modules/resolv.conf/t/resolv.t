#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
use Test::More tests => 8;
use Test::ChiselScript qw/:all/;

my $script = "scripts/resolv.conf";
my $scratch = scratch;

my $expect_norotate = <<EOT;
; normal looking file

domain foo.com
nameserver 6.28.18.11 # comment
nameserver 6.28.18.12 ; comment
nameserver 6.228.18.13
EOT

# the second resolver should be bumped up since 1.2.3.4 mod 3 is 1
my $expect_rotate = <<EOT;
; normal looking file

domain foo.com
nameserver 6.28.18.12 ; comment
nameserver 6.28.18.11 # comment
nameserver 6.28.18.13
EOT

# check no-rotate
script_ok( $scratch, $script, "t/files/norotate" );
file_is( $scratch, "/etc/resolv.conf", $expect_norotate );
files_ok( $scratch, [ qw{ /etc/resolv.conf } ] );
runlog_is( $scratch, [ "'sh' '-c' 'host transport | grep 'has address''" ] );

# check with rotation
script_ok( $scratch, $script, "t/files/rotate" );
file_is( $scratch, "/etc/resolv.conf", $expect_rotate );
files_ok( $scratch, [ qw{ /etc/resolv.conf } ] );
runlog_is( $scratch, [ "'sh' '-c' 'host transport | grep 'has address''" ] );
