#!/usr/bin/perl -w

use warnings;
use strict;
use Test::More;

my $tests = 5;
$tests += 2 if $^O eq 'linux';
plan tests => $tests;

my $script = "scripts/Scripts.pm";

require $script;

# read a blank file
my $blank = Scripts::read_file( filename => "t/files/blank" );
is( $blank, '', "read_file on a blank file" );

# read a normal looking file
my $notblank = Scripts::read_file( filename => "t/files/notblank" );
is( $notblank, "this file ::hostname::\nis not blank\n", "read_file on a normal file" );

# read a file with no newline at the end
my $nonewline = Scripts::read_file( filename => "t/files/nonewline" );
is( $nonewline, "no newline at the end of this file", "read_file on a file with no newline at the end" );

# read a file that doesn't exist
my $nonexistent = eval { Scripts::read_file( filename => "t/files/nonexistent" ); };
ok( $@ );
is( $nonexistent, undef, "read_file on a file that doesn't exist" );

# linux test: read a /proc file
if( $^O eq 'linux' ) {
    my $cpuinfo = Scripts::read_file( filename => "/proc/cpuinfo" );
    ok( $cpuinfo );
    is( $cpuinfo, `cat /proc/cpuinfo`, "read_file on /proc/cpuinfo" );
}
