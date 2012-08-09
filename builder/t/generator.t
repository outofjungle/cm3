#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 4;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN { use_ok("Chisel::Builder::Engine::Generator"); }

can_ok("Chisel::Builder::Engine::Generator", "new");
can_ok("Chisel::Builder::Engine::Generator", "generate");
can_ok("Chisel::Builder::Engine::Generator", "construct");
