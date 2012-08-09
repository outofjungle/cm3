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
  name => "include onto empty",
  yaml => tyaml( 'include rawtest' ),
  from => "",
  to   => "line one\nline two\n";

transform_test
  name => "include onto existing",
  yaml => tyaml( 'include rawtest' ),
  from => "foo\n",
  to   => "foo\nline one\nline two\n";

transform_test
  name => "include with no argument",
  yaml => tyaml( 'include' ),
  from => "",
  throws => qr/no argument/;

transform_test
  name => "include nonexistent",
  yaml => tyaml( 'include nonexistent' ),
  from => "",
  throws => qr/range error/;
