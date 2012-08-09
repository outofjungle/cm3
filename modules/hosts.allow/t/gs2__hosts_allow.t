#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
use Test::More tests => 15;
use Test::ChiselScript qw/:all/;

my $script = "scripts/hosts.allow.gs2";
my $scratch = scratch;

# just run plain (no local overrides)
script_ok( $scratch, $script, "t/files/ok/without-ipv6" );
files_ok( $scratch, [ qw{ /etc/hosts.allow } ] );
file_is( $scratch, "/etc/hosts.allow", read_file( "t/files/ok/without-ipv6/MAIN" ) );

# add a local override
system "echo HOSTS ALLOW LOCAL > $scratch/root/etc/hosts.allow.local";
script_ok( $scratch, $script, "t/files/ok/without-ipv6" );
files_ok( $scratch, [ qw{ /etc/hosts.allow /etc/hosts.allow.local } ] );
file_is( $scratch, "/etc/hosts.allow", read_file( "t/files/expected/with-local" ) );

# add a pre-local override
system "echo HOSTS ALLOW PRE LOCAL > $scratch/root/etc/hosts.allow-pre.local";
script_ok( $scratch, $script, "t/files/ok/without-ipv6" );
files_ok( $scratch, [ qw{ /etc/hosts.allow /etc/hosts.allow.local /etc/hosts.allow-pre.local } ] );
file_is( $scratch, "/etc/hosts.allow", read_file( "t/files/expected/with-both" ) );

# remove local override
unlink "$scratch/root/etc/hosts.allow.local";
script_ok( $scratch, $script, "t/files/ok/without-ipv6" );
files_ok( $scratch, [ qw{ /etc/hosts.allow /etc/hosts.allow-pre.local } ] );
file_is( $scratch, "/etc/hosts.allow", read_file( "t/files/expected/with-pre-local" ) );

# remove pre-local override
unlink "$scratch/root/etc/hosts.allow-pre.local";
script_ok( $scratch, $script, "t/files/ok/without-ipv6" );
files_ok( $scratch, [ qw{ /etc/hosts.allow } ] );
file_is( $scratch, "/etc/hosts.allow", read_file( "t/files/ok/without-ipv6/MAIN" ) );
