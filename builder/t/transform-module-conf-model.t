#!/usr/bin/perl
use warnings;
use strict;
use Log::Log4perl;
use Test::Differences;
use Test::Exception;
use Test::More tests => 1;
use Chisel::Transform;

Log::Log4perl->init( 't/files/l4p.conf' );

ok( 1 );
