#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 3;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name => "delete does not use regexes",
  yaml => tyaml( 'delete b{3}' ),
  from => "aaa\nbbb\nccc\nbbb\n",
  to   => "aaa\nbbb\nccc\nbbb\n";

transform_test
  name => "delete does not use partials",
  yaml => tyaml( 'delete b' ),
  from => "aaa\nbbb\nccc\nbbb\n",
  to   => "aaa\nbbb\nccc\nbbb\n";

transform_test
  name => "delete simple",
  yaml => tyaml( 'delete bbb' ),
  from => "aaa\nbbb\nccc\nbbb\n",
  to   => "aaa\nccc\n";
