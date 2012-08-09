#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 6;
use Test::Differences;
use Test::Exception;
use File::Temp qw/tempdir/;
use Chisel::Builder::Engine::Generator;
use Chisel::RawFile;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

# this file used to have a lot more tests for funny cases on Raw::Filesystem, which were moved to "raw-filesystem-more.t"

my $generator_ctx = Chisel::Builder::Engine::Generator::Context->new(
    raws => [
        Chisel::RawFile->new( name => 'abc', data => '123' ),
        Chisel::RawFile->new( name => 'Foo', data => 'bar' ),
        Chisel::RawFile->new( name => 'bar', data => undef ),
    ]
);

is( "123", $generator_ctx->readraw( file => "abc" ), "readraw abc" );
is( "bar", $generator_ctx->readraw( file => "Foo" ), "readraw Foo" );
is( "bar", $generator_ctx->readraw( file => "FOO" ), "readraw FOO ('same' file as Foo but different case)" );
throws_ok { $generator_ctx->readraw( file => "zzz" ) } qr/file does not exist: zzz/, "readraw fails on nonexistent";
throws_ok { $generator_ctx->readraw( file => "bar" ) } qr/file does not exist: bar/, "readraw fails on file with null data";
throws_ok { $generator_ctx->readraw() } qr/file not given/, "readraw fails if no file name is given";
