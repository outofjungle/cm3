#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 8;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name => "append on an empty file",
  yaml => tyaml( 'append test' ),
  from => "",
  to   => "test\n";

transform_test
  name => "append on an empty file",
  yaml => tyaml( 'append test' ),
  from => "",
  to   => "test\n";

transform_test
  name => "append on a file with contents",
  yaml => tyaml( [ 'append', 'test' ] ),
  from => "foo\n",
  to   => "foo\ntest\n";

transform_test
  name => "append a blank line on an empty file",
  yaml => tyaml( [ 'append', "" ] ),
  from => "",
  to   => "\n";

transform_test
  name => "append a blank line on a file with contents",
  yaml => tyaml( [ 'append', "" ] ),
  from => "foo\n",
  to   => "foo\n\n";

transform_test
  name => "append with no arguments",
  yaml => tyaml( 'append' ),
  from => "foo\n",
  to   => "foo\n\n";

transform_test
  name => "append with trailing whitespace only",
  yaml => tyaml( 'append  ' ),
  from => "foo\n",
  to   => "foo\n\n";

transform_test
  name => "two appends",
  yaml => tyaml( 'append x', 'append y' ),
  from => "foo\n",
  to   => "foo\nx\ny\n";
