#!/usr/local/bin/perl
use warnings;
use strict;
use Test::More tests => 4;
use Log::Log4perl;
use lib qw(./lib ../builder/lib ../regexp_lib/lib ../git_lib/lib ../integrity/lib);

Log::Log4perl->init( './t/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Pusher"); }

can_ok( "Chisel::Pusher", "new" );
can_ok( "Chisel::Pusher", "run" );
can_ok( "Chisel::Pusher", "push_single" );
