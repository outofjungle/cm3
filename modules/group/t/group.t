#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
use Test::More tests => 4;
use Test::ChiselScript qw/:all/;

my $script = "scripts/group";
my $scratch = scratch;

script_ok( $scratch, $script, "t/files/ok/normal" );

if( $^O eq 'linux' ) {
    files_ok( $scratch, [ qw{ /etc/group } ] );
    file_is( $scratch, "/etc/group", scalar `cat t/files/ok/normal/linux` );
    runlog_is( $scratch, [ "'sh' '-c' 'grpconv'" ] );
}

elsif( $^O eq 'freebsd' ) {
    files_ok( $scratch, [ qw{ /etc/group } ] );
    file_is( $scratch, "/etc/group", scalar `cat t/files/ok/normal/freebsd` );
    runlog_is( $scratch, [] );
}
