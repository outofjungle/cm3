#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 3;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN { use_ok( "Chisel::Builder::Overmind" ); }

can_ok( "Chisel::Builder::Overmind", "new" );
can_ok( "Chisel::Builder::Overmind", "run" );
