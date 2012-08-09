#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 2;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN {
    use_ok( "Chisel::Builder::Group" );
    use_ok( "Chisel::Builder::Group::Roles" );
}
