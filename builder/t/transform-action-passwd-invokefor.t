#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 6;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

# test invokefor + "add" (it's really common)
transform_test
  name  => "invokefor + add {}",
  yaml  => tyaml( 'invokefor someusers add {}' ),
  from  => "foo:x:1:a\n",
  to    => "foo:x:1:a\nbob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

transform_test
  name  => "invokefor + add {}, 3-arg",
  yaml  => tyaml( [qw/invokefor someusers add {}/] ),
  from  => "foo:x:1:a\n",
  to    => "foo:x:1:a\nbob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

transform_test
  name  => "invokefor + add {, }",
  yaml  => tyaml( 'invokefor someusers add {, }' ),
  from  => "foo:x:1:a\n",
  to    => "foo:x:1:a\nbob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

# test invokefor + "remove" (also used from time to time)
transform_test
  name  => "invokefor + remove {}",
  yaml  => tyaml( 'invokefor someusers remove {}' ),
  from  => "foo:x:1:a\nbob:a:10000:b\ncarol:r:20000:s\n",
  to    => "foo:x:1:a\n",
  model => "Passwd";

transform_test
  name  => "invokefor + remove {}, 3-arg",
  yaml  => tyaml( [qw/invokefor someusers remove {}/] ),
  from  => "foo:x:1:a\nbob:a:10000:b\ncarol:r:20000:s\n",
  to    => "foo:x:1:a\n",
  model => "Passwd";

transform_test
  name  => "invokefor + remove {, }",
  yaml  => tyaml( 'invokefor someusers remove {, }' ),
  from  => "foo:x:1:a\nbob:a:10000:b\ncarol:r:20000:s\n",
  to    => "foo:x:1:a\n",
  model => "Passwd";
