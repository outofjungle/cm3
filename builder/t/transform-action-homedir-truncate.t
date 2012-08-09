#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 2;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name  => "truncate on empty",
  yaml  => tyaml( 'truncate' ),
  from  => "",
  to    => "--- {}\n",
  model => "Homedir";

transform_test
  name  => "truncate on existing",
  yaml  => tyaml( 'truncate' ),
  from  => "foo: [ bar ]\nbaz: [ qux ]",
  to    => "--- {}\n",
  model => "Homedir";
