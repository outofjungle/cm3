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
  name  => "delete from empty",
  yaml  => tyaml( 'delete bob' ),
  from  => "",
  to    => "",
  model => "Passwd";

transform_test
  name  => "delete from existing",
  yaml  => tyaml( 'delete bob:a:10000:b' ),
  from  => "bob:a:10000:b\ncarol:r:20000:s\n",
  to    => "carol:r:20000:s\n",
  model => "Passwd";

transform_test
  name  => "delete with not enough of a line given",
  yaml  => tyaml( 'delete bob' ),
  from  => "bob:a:10000:b\ncarol:r:20000:s\n",
  to    => "bob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

transform_test
  name  => "delete with partial username",
  yaml  => tyaml( [ 'delete', 'bo' ] ),
  from  => "bob:a:10000:b\ncarol:r:20000:s\n",
  to    => "bob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";
