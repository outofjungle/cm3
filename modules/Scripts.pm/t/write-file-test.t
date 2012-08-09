#!/usr/bin/perl -w

use warnings;
use strict;
use Test::More tests => 30;
use File::Temp qw/tempdir/;

my $script = "scripts/Scripts.pm";

require $script;

my $tmp = tempdir( CLEANUP => 1 );

my $r;

# test: failing, nonexistent file, without 'cmd'
$r = eval { Scripts::write_file( filename => "$tmp/notblank", contents => "new2\n", test => "exit 1" ); };
ok($@); # should have failed
is( $r, undef );
is_deeply( [sort split "\n", qx[find $tmp -type f]], [] ); # should not be any files in here

# test: failing, nonexistent file, with 'cmd'
$r = eval { Scripts::write_file( filename => "$tmp/notblank", contents => "new2\n", test => "exit 1", cmd => "echo -n x >> $tmp/touched ; cat $tmp/notblank >> $tmp/touched" ); };
ok($@); # should have failed
is( $r, undef );
is( `cat $tmp/touched`, "xnew2\nx" ); # should have been run twice, and contain only one copy of the contents we tried to write
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/touched" ] );

# test: working, nonexistent file, with 'cmd'
unlink "$tmp/touched";
$r = Scripts::write_file( filename => "$tmp/notblank", contents => "new2\n", test => "exit 0" );
ok($r); # should be true since file changed
is( `cat $tmp/notblank`, "new2\n" );
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank" ] );

# test 'test' + 'cmd' not doing anything when the file isn't changing
$r = Scripts::write_file( filename => "$tmp/notblank", contents => "new2\n", cmd => "echo x > $tmp/touched", test => "echo x > $tmp/touched2" );
ok(!$r); # should be false since the file didn't change
is( `cat $tmp/notblank`, "new2\n" );
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank" ] ); # no extra files should be generated

# test: working, existing file, without 'cmd'
$r = Scripts::write_file( filename => "$tmp/notblank", contents => "new\n", test => "exit 0" );
ok($r); # should be true
is( `cat $tmp/notblank`, "new\n" ); # should have the new contents
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank" ] ); # no extra files should be generated

# test: failing, existing file, without 'cmd'
$r = eval { Scripts::write_file( filename => "$tmp/notblank", contents => "new2\n", test => "exit 1" ); };
ok($@); # should have failed
is( $r, undef );
is( `cat $tmp/notblank`, "new\n" ); # should have the old contents
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank" ] ); # no extra files

# test: working, existing file, with 'cmd'
$r = Scripts::write_file( filename => "$tmp/notblank", contents => "new2\n", test => "exit 0", cmd => "echo -n x >> $tmp/touched ; cat $tmp/notblank >> $tmp/touched" );
ok($r); # should be true
is( `cat $tmp/notblank`, "new2\n" );
is( `cat $tmp/touched`, "xnew2\n" ); # should have been run only once
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank", "$tmp/touched" ] );

# test: failing, existing file, with 'cmd'
unlink "$tmp/touched";
is( `cat $tmp/notblank`, "new2\n" );
$r = eval { Scripts::write_file( filename => "$tmp/notblank", contents => "new\n", test => "exit 1", cmd => "echo -n x >> $tmp/touched ; cat $tmp/notblank >> $tmp/touched" ); };
ok($@); # should have failed
is( $r, undef );
is( `cat $tmp/notblank`, "new2\n" ); # contents should not have changed
is( `cat $tmp/touched`, "xnew\nxnew2\n" ); # should have been run twice, and contain one copy of the bad file and one copy of the good file
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank", "$tmp/touched" ] );
