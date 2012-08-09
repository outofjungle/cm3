#!/usr/local/bin/perl

# bucket-add.t -- mostly focuses on tests of add(), has some incidental tests of manifest() and manifest_json()

use warnings;
use strict;
use Digest::MD5 qw/md5_hex/;
use File::Temp qw/tempdir/;
use Test::More tests => 17;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Bucket"); }

my $bucket = Chisel::Bucket->new;

# add a file with every key under the sun
$bucket->add( file => "xxx", blob => "4e6775bc460b96adb0a96b7304d673aa0dc98758", md5 => "bf97e2e728cf208279a775dcd6db4c90", mtime => 12345 );

# add a file with minimum key set
$bucket->add( file => "abc", blob => "0f48548c3a3d2eeba8ee57f063c2215360d4576d" );

# blob is too long by 1 character
throws_ok { $bucket->add( file => "abc", blob => "f2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" ); 1; } qr/unrecognized blob/, "add with bad 'blob' format fails";

# try add()ing without 'blob' (required)
throws_ok { $bucket->add( file => "def" ); 1; } qr/blob not given/, "add() without 'blob' fails";

# try add()ing without 'file' (required)
throws_ok { $bucket->add( blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" ); 1; } qr/file not given/, "add() without 'file' fails";

# try various paths to see what is accepted -- first a few that should
$bucket->add( file => "foo/bar",      blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" );
$bucket->add( file => "foo/baz/qux",  blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" );
$bucket->add( file => "foo/.baz/qux", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" );
$bucket->add( file => "scripts/bar",  blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" );
$bucket->add( file => ".a",           blob => "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" );
$bucket->add( file => ".b/c",         blob => "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" );

# try various paths to see what is accepted -- now a few that shouldn't
throws_ok { $bucket->add( file => "/foo/bar/qux", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" ); 1; } qr/bad file name: \/foo\/bar\/qux/,
  "add() of a file with an invalid name (leading slash)";

throws_ok { $bucket->add( file => "foo/bar/qux", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" ); 1; } qr/new file foo\/bar\/qux conflicts with existing file/,
  "add() of a file underneath another file fails";

throws_ok { $bucket->add( file => "foo", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" ); 1; } qr/new file foo conflicts with existing file/,
  "add() of a file over a directory fails";

throws_ok { $bucket->add( file => "foo/../xxx", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" ); 1; } qr/bad file name/,
  "add() of a file with '..' path component fails";

throws_ok { $bucket->add( file => "../foo/xxx", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" ); 1; } qr/bad file name/,
  "add() of a file with '..' path starter fails";

throws_ok { $bucket->add( file => ".", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" ); 1; } qr/bad file name/,
  "add() of '.' by itself fails";

throws_ok { $bucket->add( file => "..", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" ); 1; } qr/bad file name/,
  "add() of '..' by itself fails";

# try adding "foo/bar" multiple times
# this tests the fact that later adds will overwrite earlier ones
$bucket->add( file => "foo/bar", blob => "5555555555555555555555555555555555555555" );
$bucket->add( file => "foo/bar", blob => "6666666666666666666666666666666666666666" );
$bucket->add( file => "foo/bar", blob => "7777777777777777777777777777777777777777" );

###
# adds are done, now check tree(), manifest() and manifest_json()
###

# check stringification and ->tree
is( $bucket->tree, "95dedbe716808133339707814aa61803bda5fd47", "bucket tree sha is correct" );
is( "$bucket", "95dedbe716808133339707814aa61803bda5fd47", "bucket stringifies as its tree sha" );

eq_or_diff(
    $bucket->manifest( emit => ['blob'] ),
    {
        "abc" =>          { name => "abc",         type => "file", mode => "0644", blob => "0f48548c3a3d2eeba8ee57f063c2215360d4576d" },
        "foo/bar" =>      { name => "foo/bar",     type => "file", mode => "0644", blob => "7777777777777777777777777777777777777777" },
        "foo/baz/qux" =>  { name => "foo/baz/qux", type => "file", mode => "0644", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" },
        "scripts/bar" =>  { name => "scripts/bar", type => "file", mode => "0755", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" },
        "xxx" =>          { name => "xxx",         type => "file", mode => "0644", blob => "4e6775bc460b96adb0a96b7304d673aa0dc98758" },
    },
    "manifest( emit => ['blob'] ) includes all add()'d non-dotfiles"
);

eq_or_diff(
    $bucket->manifest_json( emit => [ 'blob' ] ),
    join( "\n", 
        '{"blob":"0f48548c3a3d2eeba8ee57f063c2215360d4576d","mode":"0644","name":["abc"],"type":"file"}',
        '{"blob":"7777777777777777777777777777777777777777","mode":"0644","name":["foo/bar"],"type":"file"}',
        '{"blob":"2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610","mode":"0644","name":["foo/baz/qux"],"type":"file"}',
        '{"blob":"2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610","mode":"0755","name":["scripts/bar"],"type":"file"}',
        '{"blob":"4e6775bc460b96adb0a96b7304d673aa0dc98758","mode":"0644","name":["xxx"],"type":"file"}',
        '' # to get the trailing newline to show up
    ),
    "manifest_json( emit => ['blob'] ) includes all add()'d non-dotfiles"
);

eq_or_diff(
    $bucket->manifest( emit => ['blob'], include_dotfiles => 1 ),
    {
        ".a" =>           { name => ".a",           type => "file", mode => "0644", blob => "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        ".b/c" =>         { name => ".b/c",         type => "file", mode => "0644", blob => "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
        "abc" =>          { name => "abc",          type => "file", mode => "0644", blob => "0f48548c3a3d2eeba8ee57f063c2215360d4576d" },
        "foo/.baz/qux" => { name => "foo/.baz/qux", type => "file", mode => "0644", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" },
        "foo/bar" =>      { name => "foo/bar",      type => "file", mode => "0644", blob => "7777777777777777777777777777777777777777" },
        "foo/baz/qux" =>  { name => "foo/baz/qux",  type => "file", mode => "0644", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" },
        "scripts/bar" =>  { name => "scripts/bar",  type => "file", mode => "0755", blob => "2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610" },
        "xxx" =>          { name => "xxx",          type => "file", mode => "0644", blob => "4e6775bc460b96adb0a96b7304d673aa0dc98758" },
    },
    "manifest( emit => ['blob'], include_dotfiles => 1 ) includes all add()'d files and dotfiles"
);

eq_or_diff(
    $bucket->manifest_json( emit => [ 'blob' ], include_dotfiles => 1 ),
    join( "\n", 
        '{"blob":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","mode":"0644","name":[".a"],"type":"file"}',
        '{"blob":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","mode":"0644","name":[".b/c"],"type":"file"}',
        '{"blob":"0f48548c3a3d2eeba8ee57f063c2215360d4576d","mode":"0644","name":["abc"],"type":"file"}',
        '{"blob":"2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610","mode":"0644","name":["foo/.baz/qux"],"type":"file"}',
        '{"blob":"7777777777777777777777777777777777777777","mode":"0644","name":["foo/bar"],"type":"file"}',
        '{"blob":"2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610","mode":"0644","name":["foo/baz/qux"],"type":"file"}',
        '{"blob":"2f186b4f54d943ca79dc4f8bfbcc3748dd7e2610","mode":"0755","name":["scripts/bar"],"type":"file"}',
        '{"blob":"4e6775bc460b96adb0a96b7304d673aa0dc98758","mode":"0644","name":["xxx"],"type":"file"}',
        '' # to get the trailing newline to show up
    ),
    "manifest_json( emit => ['blob'], include_dotfiles => 1 ) includes all add()'d files and dotfiles"
);
