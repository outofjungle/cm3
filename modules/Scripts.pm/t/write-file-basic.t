#!/usr/bin/perl -w

use warnings;
use strict;
use Test::More tests => 21;
use File::Temp qw/tempdir/;

my $script = "scripts/Scripts.pm";

require $script;

my $tmp = tempdir( CLEANUP => 1 );

my ( $contents, $r );
chomp( my $hostname = `hostname` );

# write a simple file, with the original not there
$contents = "this file ::hostname::\nis not blank\n";
$r = Scripts::write_file( filename => "$tmp/notblank", contents => $contents );
ok($r); # should be true
is( `cat $tmp/notblank`, $contents );
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank" ] );
is( (stat "$tmp/notblank")[2] & 0777, 0644 ); # default mode is 0644

# write it again, it shouldn't change
$r = Scripts::write_file( filename => "$tmp/notblank", contents => $contents );
ok(!$r); # should be false
is( `cat $tmp/notblank`, $contents );
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank" ] );

# write it with different contents, it should change. test 'template' at the same time
$r = Scripts::write_file( filename => "$tmp/notblank", contents => $contents, template => 1 );
ok($r); # should be true
is( `cat $tmp/notblank`, "this file $hostname\nis not blank\n" );
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank" ] );

# test 'mode'
$r = Scripts::write_file( filename => "$tmp/notblank", contents => $contents, mode => 0600 );
ok($r); # should be true, since the file changed
is( `cat $tmp/notblank`, $contents );
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank" ] );
is( (stat "$tmp/notblank")[2] & 0777, 0600 );

# test 'cmd' not doing anything
$r = Scripts::write_file( filename => "$tmp/notblank", contents => $contents, cmd => "touch $tmp/touched", mode => 0600 );
ok(!$r); # should be false, since the file didn't change
is( `cat $tmp/notblank`, $contents );
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank" ] ); # "touched" should not have been created

# test 'cmd' doing something
$r = Scripts::write_file( filename => "$tmp/notblank", contents => "x$contents", cmd => "echo x >> $tmp/touched", mode => 0600 );
ok($r); # should be true
is( `cat $tmp/notblank`, "x$contents" );
is( `cat $tmp/touched`, "x\n" );
is_deeply( [sort split "\n", qx[find $tmp -type f]], [ "$tmp/notblank", "$tmp/touched" ] );
unlink "$tmp/touched";
