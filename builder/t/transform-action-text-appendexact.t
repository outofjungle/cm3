#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 7;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name => "appendexact on an empty file",
  yaml => tyaml( 'appendexact test' ),
  from => "",
  to   => "test";

transform_test
  name => "appendexact on a file with contents",
  yaml => tyaml( [ 'appendexact', 'test' ] ),
  from => "foo\n",
  to   => "foo\ntest";

transform_test
  name => "appendexact a blank line on an empty file",
  yaml => tyaml( [ 'appendexact', "" ] ),
  from => "",
  to   => "";

transform_test
  name => "appendexact a blank line on a file with contents",
  yaml => tyaml( [ 'appendexact', "" ] ),
  from => "foo\n",
  to   => "foo\n";

transform_test
  name => "appendexact with no arguments",
  yaml => tyaml( 'appendexact' ),
  from => "foo\n",
  to   => "foo\n";

transform_test
  name => "appendexact with trailing whitespace only",
  yaml => tyaml( 'appendexact  ' ),
  from => "foo\n",
  to   => "foo\n";

transform_test
  name => "two appendexacts",
  yaml => tyaml( 'appendexact x', 'appendexact y' ),
  from => "foo\n",
  to   => "foo\nxy";
