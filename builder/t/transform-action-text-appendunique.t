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
  name => "appendunique on an empty file",
  yaml => tyaml( 'appendunique test' ),
  from => "",
  to   => "test\n";

transform_test
  name => "appendunique on an empty file",
  yaml => tyaml( 'appendunique test' ),
  from => "",
  to   => "test\n";

transform_test
  name => "appendunique on a file with contents",
  yaml => tyaml( [ 'appendunique', 'test' ] ),
  from => "foo\n",
  to   => "foo\ntest\n";

transform_test
  name => "appendunique a line that already exists (1-arg)",
  yaml => tyaml( 'appendunique foo' ),
  from => "foo\n",
  to   => "foo\n";

transform_test
  name => "appendunique a line that already exists (2-arg)",
  yaml => tyaml( [ 'appendunique', "foo" ] ),
  from => "foo\n",
  to   => "foo\n";

transform_test
  name => "appendunique with no arguments",
  yaml => tyaml( 'appendunique' ),
  from => "foo\n",
  to   => "foo\n\n";

transform_test
  name => "appendunique a blank line on a file with contents (1-arg)",
  yaml => tyaml( 'appendunique  ', 'appendunique  ' ),
  from => "foo\n",
  to   => "foo\n\n";

transform_test
  name => "appendunique a blank line on a file with contents (2-arg)",
  yaml => tyaml( [ 'appendunique', "" ], [ 'appendunique', "" ] ),
  from => "foo\n",
  to   => "foo\n\n";
