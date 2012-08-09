#!/usr/local/bin/perl -w
use strict;
use Test::More;
use Test::More tests => 7;
use Test::Exception;
use Log::Log4perl;
my $LIB = "-It/lib -Ilib -I../builder/lib -I../regexp_lib/lib -I../git_lib/lib -I../integrity/lib";

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Reporter::Puller"); }

can_ok( "Chisel::Reporter::Puller", "get_node_id" );
can_ok( "Chisel::Reporter::Puller", "get_script_id" );
can_ok( "Chisel::Reporter::Puller", "logger" );
can_ok( "Chisel::Reporter::Puller", "new" );
can_ok( "Chisel::Reporter::Puller", "run" );

ok( 0 == system( "/usr/local/bin/perl -wc $LIB bin/reporter_puller 2>/dev/null" ), "reporter_puller syntax" );
