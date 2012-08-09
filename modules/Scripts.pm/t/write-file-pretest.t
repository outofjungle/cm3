#!/usr/bin/perl -w

use warnings;
use strict;
use Test::More tests => 32;
use File::Temp qw/tempdir/;

my $script = "scripts/Scripts.pm";

require $script;

my $tmp = tempdir( CLEANUP => 1 );

my $r;

# if pretest fails, no file should be written
$r = eval { Scripts::write_file( filename => "$tmp/notblank", contents => "new\n", pretest => "exit 1" ); };
ok($@); # should have failed
is( $r, undef );
is_deeply( [sort split "\n", qx[find $tmp -type f]], [] ); # should not be any files in here

# if pretest passes, the file should be written
$r = Scripts::write_file( filename => "$tmp/notblank", contents => "new\n", pretest => "exit 0" );
ok($r); # should be true since the file changed
is( `cat $tmp/notblank`, "new\n" );
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank" ] );

# pretest should not be run if the file doesn't change
$r = Scripts::write_file( filename => "$tmp/notblank", contents => "new\n", pretest => "echo x > $tmp/touched" );
ok(!$r); # should be false
is( `cat $tmp/notblank`, "new\n" );
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank" ] ); # no extra files should be generated

# if pretest fails, the file should not change and 'cmd' should never be run
$r = eval { Scripts::write_file( filename => "$tmp/notblank", contents => "new2\n", pretest => "exit 1", cmd => "echo x > $tmp/touched" ); };
ok($@); # should have failed
is( $r, undef );
is( `cat $tmp/notblank`, "new\n" ); # should have the old contents
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank" ] ); # no extra files

# if pretest succeeds, 'cmd' should be run and file should change
$r = Scripts::write_file( filename => "$tmp/notblank", contents => "new2\n", pretest => "exit 0", cmd => "echo x > $tmp/touched" );
ok($r); # should be true
is( `cat $tmp/notblank`, "new2\n" ); # should have the new contents
is( `cat $tmp/touched`, "x\n" ); # from cmd
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank", "$tmp/touched" ] ); # cmd should make an extra file

# pretest should replace {} with the file name
unlink "$tmp/touched", "$tmp/notblank";
$r = Scripts::write_file( filename => "$tmp/notblank", contents => "new2\n", pretest => "echo {} > $tmp/touched ; cat {} > $tmp/touched2" );
ok($r); # should be true
is( `cat $tmp/notblank`, "new2\n" ); # should have the new contents
like( `cat $tmp/touched`, qr/notblank\.secotemp\.\d+$/ ); # from env var
is( `cat $tmp/touched2`, "new2\n" ); # from env var
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank", "$tmp/touched", "$tmp/touched2" ] );

# ensure it works even with quoted arguments
unlink "$tmp/touched", "$tmp/notblank", "$tmp/touched2";
$r = Scripts::write_file( filename => "$tmp/notblank", contents => "new2\n", pretest => "echo '^root:[^:]+:0:' > $tmp/touched" );
ok($r); # should be true
is( `cat $tmp/notblank`, "new2\n" ); # should have the new contents
is( `cat $tmp/touched`, "^root:[^:]+:0:\n" ); # from env var
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank", "$tmp/touched" ] );

# ensure it works even with a nightmarish filename
unlink "$tmp/touched", "$tmp/notblank", "$tmp/touched2";
is_deeply( [sort split "\n", qx[find $tmp -type f]], [] );
$r = Scripts::write_file( filename => "$tmp/ch\" \'", contents => "new2\n", pretest => "echo {} > $tmp/touched ; cat {} > $tmp/touched2" );
ok($r); # should be true
is( `cat "$tmp/ch\\" '"`, "new2\n" ); # should have the new contents
like( `cat $tmp/touched`, qr/ch\" \'\.secotemp\.\d+$/ ); # from env var
is( `cat $tmp/touched2`, "new2\n" ); # from env var
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/ch\" \'", "$tmp/touched", "$tmp/touched2" ] );
