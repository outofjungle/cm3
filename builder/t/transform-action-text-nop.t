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
  name => "nop on empty file",
  yaml => tyaml( 'nop' ),
  from => "",
  to   => "";

transform_test
  name => "nop with an argument (list form)",
  yaml => tyaml( [ 'nop', 'xxx' ] ),
  from => "foo\n",
  to   => "foo\n";

transform_test
  name => "nop with an argument (non-list form) on a file with contents",
  yaml => tyaml( 'nop xxx' ),
  from => "foo\n",
  to   => "foo\n";
