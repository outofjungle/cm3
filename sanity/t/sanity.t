#!/usr/local/bin/perl

# sanity.t -- barely checks anything, just ensures the public interface exists

use warnings;
use strict;
use Test::More tests => 4;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Sanity"); }

can_ok( "Chisel::Sanity", "new" );
can_ok( "Chisel::Sanity", "add_blob" );
can_ok( "Chisel::Sanity", "check_bucket" );
