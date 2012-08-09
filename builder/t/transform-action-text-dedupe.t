#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 1;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name => "dedupe",
  yaml => tyaml( 'dedupe' ),
  from => "aaa\nbbb\nccc\nbbb\naaa\n",
  to   => "aaa\nbbb\nccc\n";
