#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
use Test::More tests => 6;
use Test::ChiselScript qw/:all/;

my $script = "scripts/motd";
my $scratch = scratch;

# check that it creates the right file
script_ok( $scratch, $script, "t/files" );
file_is( $scratch, "/etc/motd", "test motd\n" );
files_ok( $scratch, [ qw{ /etc/motd } ] );

# tweak disk file
open my $fh, ">", "$scratch/root/etc/motd";
print $fh "xxx\n";
close $fh;
file_is( $scratch, "/etc/motd", "xxx\n" );

# make sure it's fixed
script_ok( $scratch, $script, "t/files" );
file_is( $scratch, "/etc/motd", "test motd\n" );
