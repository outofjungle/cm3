#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
use Test::More tests => 5;
use Test::ChiselScript qw/:all/;

my $script = "scripts/passwd";
my $scratch = scratch;


if( $^O eq 'linux' ) {
    script_ok( $scratch, $script, "t/files/ok/normal" );

    files_ok( $scratch, [ qw{ /etc/passwd /etc/shadow } ] );
    file_is( $scratch, "/etc/passwd", read_file( "t/files/ok/normal/linux" ) );
    file_is( $scratch, "/etc/shadow", read_file( "t/files/ok/normal/shadow" ) );
    mode_is( $scratch, "/etc/shadow", 0400 );
    # runlog_is( $scratch, [] );
}

elsif( $^O eq 'freebsd' ) {
    # put a dummy master.passwd file in (passwd script needs it on freebsd)
    mkdir "$scratch/root/etc";
    system( "echo 'dummy' > $scratch/root/etc/master.passwd" );
    
    script_ok( $scratch, $script, "t/files/ok/normal" );
    files_ok( $scratch, [ qw{ /etc/master.passwd /etc/.master.passwd.chisel } ] );
    file_is( $scratch, "/etc/.master.passwd.chisel", read_file( "t/files/ok/normal/freebsd" ) );
    mode_is( $scratch, "/etc/.master.passwd.chisel", 0600 );
    # runlog_is( $scratch, [ "'sh' '-c' 'pwd_mkdb -p /etc/.master.passwd.chisel'" ] );
    pass(); # dummy test
}
