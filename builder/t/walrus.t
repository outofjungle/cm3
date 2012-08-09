#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 5;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN { use_ok("Chisel::Builder::Engine::Walrus"); }

can_ok("Chisel::Builder::Engine::Walrus", "new");
can_ok("Chisel::Builder::Engine::Walrus", "range");
can_ok("Chisel::Builder::Engine::Walrus", "host_transforms");

my $walrus = Chisel::Builder::Engine::Walrus->new;

isa_ok($walrus, "Chisel::Builder::Engine::Walrus", "Walrus object creation");
