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
  name => "prepend on an empty file",
  yaml => tyaml( 'prepend test' ),
  from => "",
  to   => "test\n";

transform_test
  name => "prepend on an empty file",
  yaml => tyaml( 'prepend test' ),
  from => "",
  to   => "test\n";

transform_test
  name => "prepend on a file with contents",
  yaml => tyaml( [ 'prepend', 'test' ] ),
  from => "foo\n",
  to   => "test\nfoo\n";

transform_test
  name => "prepend a blank line on an empty file",
  yaml => tyaml( [ 'prepend', "" ] ),
  from => "",
  to   => "\n";

transform_test
  name => "prepend a blank line on a file with contents",
  yaml => tyaml( [ 'prepend', "" ] ),
  from => "foo\n",
  to   => "\nfoo\n";

transform_test
  name => "prepend with no arguments",
  yaml => tyaml( 'prepend' ),
  from => "foo\n",
  to   => "\nfoo\n";

transform_test
  name => "prepend with trailing whitespace only",
  yaml => tyaml( 'prepend  ' ),
  from => "foo\n",
  to   => "\nfoo\n";
