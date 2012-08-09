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
  name  => "dedupe empty",
  yaml  => tyaml( 'dedupe' ),
  from  => "",
  to    => "",
  model => "Passwd";

transform_test
  name => "dedupe existing",
  yaml => tyaml( 'sortuid' ),
  from  => "carol:r:1:s\ndave:a:2:b\nbob:a:3:b\nbob:a:3:b\n",
  to    => "carol:r:1:s\ndave:a:2:b\nbob:a:3:b\n",
  model => "Passwd";
