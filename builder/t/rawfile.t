#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 36;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN { use_ok( "Chisel::RawFile" ); }

# make a basic raw file
my $raw = Chisel::RawFile->new( name => "x/y", data => "hello world\n" );
is( $raw->name,         "x/y",                                          "raw file name is correct (1)" );
is( $raw->data,         "hello world\n",                                "raw file data is correct (1)" );
is( $raw->decode,       "hello world\n",                                "raw file decode is correct (1)" );
is( $raw->blob,         '3b18e512dba79e4c8300dd08aeb37f8e728b8dad',     "raw file blob is correct (1)" );
is( $raw->id,           'x/y@3b18e512dba79e4c8300dd08aeb37f8e728b8dad', "raw file id is correct (1)" );
is( $raw->ts,           0,                                              "raw file timestamp defaults to zero (1)" );
is( $raw->data_pending, undef,                                          "raw file review text defaults to undef (1)" );
is( $raw->blob_pending, undef,                                          "raw file review blob defaults to undef (1)" );

# make a raw file with timestamp and which also needs review
my $raw2 = Chisel::RawFile->new( name => "xxx", data => "hello world\n", ts => 999, data_pending => "new datas\n" );
is( $raw2->name,         "xxx",                                          "raw file name is correct (2)" );
is( $raw2->data,         "hello world\n",                                "raw file data is correct (2)" );
is( $raw2->decode,       "hello world\n",                                "raw file decode is correct (2)" );
is( $raw2->blob,         '3b18e512dba79e4c8300dd08aeb37f8e728b8dad',     "raw file blob is correct (1)" );
is( $raw2->id,           'xxx@3b18e512dba79e4c8300dd08aeb37f8e728b8dad', "raw file id is correct (1)" );
is( $raw2->ts,           999,                                            "raw file timestamp is correct (2)" );
is( $raw2->data_pending, "new datas\n",                                  "raw file review text is correct (2)" );
is( $raw2->blob_pending, "fd67e4a7fd55c222ae7963e38f0814d4a04c02c8",     "raw file review blob is correct (2)" );

# make a raw file with no data (this is ok, if it's a placeholder)
my $raw3 = Chisel::RawFile->new( name => "zzz", data => undef );
is( $raw3->name,        "zzz", "raw file name is correct (3)" );
is( $raw3->data,        undef, "raw file data is correct (3)" );
is( $raw3->decode,      undef, "raw file decode is correct (3)" );
is( $raw3->blob,        undef, "raw file blob is correct (3)" );
is( $raw3->id,          undef, "raw file id is correct (3)" );
is( $raw3->ts,          0,     "raw file timestamp is correct (3)" );
is( $raw3->data_pending, undef, "raw file review text is correct (3)" );
is( $raw3->blob_pending, undef, "raw file review blob is correct (3)" );

# make a raw file with unicode data. should be stored as the utf-8 encoded version
my $raw4 = Chisel::RawFile->new( name => "unicode", data => "SMILE! \x{263A}" );    # U+263A WHITE SMILING FACE
is( $raw4->name,   "unicode",                                          "raw file name is correct (4)" );
is( $raw4->data,   "SMILE! \xe2\x98\xba",                              "raw file data is correct (4)" );
is( $raw4->decode, "SMILE! \x{263A}",                                  "raw file decode is correct (4)" );
is( $raw4->blob,   '393d61cd5efffcb47f26d769e4ea6eb22d69c57e',         "raw file blob is correct (4)" );
is( $raw4->id,     'unicode@393d61cd5efffcb47f26d769e4ea6eb22d69c57e', "raw file id is correct (4)" );
is( $raw4->ts,     0,                                                  "raw file timestamp defaults to zero (4)" );
is( $raw4->data_pending, undef, "raw file review text defaults to undef (4)" );
is( $raw4->blob_pending, undef, "raw file review blob defaults to undef (4)" );

# try some bogus files
throws_ok { Chisel::RawFile->new( name => "",     data => "hello world\n" ) } qr/raw 'name' is not well-formatted/;
throws_ok { Chisel::RawFile->new( name => ".xxx", data => "hello world\n" ) } qr/raw 'name' is not well-formatted/;
throws_ok { Chisel::RawFile->new( name => "x/y",  data => "hello world\n", ts => 'x' ) }
qr/raw 'ts' is not well-formatted/;
