#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
use Test::More tests => 6;
use Test::ChiselScript qw/:all/;

my $script = "scripts/ntp.conf";
my $scratch = scratch;
my $MAIN = "server 216.145.54.95\nrestrict default ignore\nrestrict 216.145.54.95\n";

# check that it creates the right file
script_ok( $scratch, $script, "t/files" );
file_is( $scratch, "/etc/ntp.conf", $MAIN );
files_ok( $scratch, [ qw{ /etc/ntp.conf } ] );

# tweak disk file
open my $fh, ">", "$scratch/root/etc/ntp.conf";
print $fh "xxx\n";
close $fh;
file_is( $scratch, "/etc/ntp.conf", "xxx\n" );

# make sure it's fixed
script_ok( $scratch, $script, "t/files" );
file_is( $scratch, "/etc/motd", $MAIN );

