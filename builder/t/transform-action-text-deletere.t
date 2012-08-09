#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 4;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name => "deletere simple",
  yaml => tyaml( 'deletere b{3}' ),
  from => "aaa\nbbb\nccc\nbbb\n",
  to   => "aaa\nccc\n";

transform_test
  name => "deletere simple do-nothing",
  yaml => tyaml( 'deletere d{3}' ),
  from => "aaa\nbbb\nccc\nbbb\n",
  to   => "aaa\nbbb\nccc\nbbb\n";

transform_test
  name => "deletere multi-match",
  yaml => tyaml( 'deletere [ab]{3}' ),
  from => "aaa\nbbb\nccc\nbbb\n",
  to   => "ccc\n";

transform_test
  name => "deletere partial match",
  yaml => tyaml( 'deletere b' ),
  from => "aaa\nbbb\nccc\nbbb\n",
  to   => "aaa\nccc\n";
