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
  name => "unlink a file",
  yaml => tyaml( 'unlink' ),
  from => "foo\n",
  ret  => 0;

transform_test
  name => "unlink a file (list form)",
  yaml => tyaml( ['unlink'] ),
  from => "foo\n",
  ret  => 0;
