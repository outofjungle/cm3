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
  name => "use onto empty",
  yaml => tyaml( 'use rawtest' ),
  from => "",
  to   => "line one\nline two\n";

transform_test
  name => "use onto existing",
  yaml => tyaml( 'use rawtest' ),
  from => "foo\n",
  to   => "line one\nline two\n";

transform_test
  name => "use with no argument",
  yaml => tyaml( 'use' ),
  from => "",
  throws => qr/no argument/;

transform_test
  name => "use nonexistent",
  yaml => tyaml( 'use nonexistent' ),
  from => "",
  throws => qr/range error/;
