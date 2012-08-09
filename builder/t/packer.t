#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 3;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN { use_ok("Chisel::Builder::Engine::Packer"); }

can_ok("Chisel::Builder::Engine::Packer", "new");
can_ok("Chisel::Builder::Engine::Packer", "pack");
