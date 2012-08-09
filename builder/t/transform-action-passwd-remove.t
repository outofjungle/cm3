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
  name => "remove from empty",
  yaml => tyaml( 'remove bob' ),
  from => "",
  to   => "",
  model => "Passwd";

transform_test
  name => "remove from existing",
  yaml => tyaml( 'remove bob' ),
  from => "bob:a:10000:b\ncarol:r:20000:s\n",
  to   => "carol:r:20000:s\n",
  model => "Passwd";

transform_test
  name => "remove nonexistent",
  yaml => tyaml( 'remove xxx' ),
  from => "bob:a:10000:b\ncarol:r:20000:s\n",
  to   => "bob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

transform_test
  name => "remove multi-arg",
  yaml => tyaml( ['remove', 'bob', 'carol'] ),
  from => "bob:a:10000:b\ncarol:r:20000:s\n",
  to   => "",
  model => "Passwd";

transform_test
  name => "remove mixing commas, multi-arg, and nonexistent users",
  yaml => tyaml( [ 'remove', 'bob, nobody7', 'sshd, nobody2, nobody7, bob, carol' ] ),
  from => "bob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:f\nnobody7:x:65534:z\nsshd:x:75:q\n",
  to   => "dave:x:30000:f\n",
  model => "Passwd";

transform_test
  name => "remove mixed with add",
  yaml => tyaml( 'add bob, carol, dave', 'remove carol', 'add carol', [ 'remove', 'bob', 'xxx' ] ),
  from => "",
  to   => "carol:r:20000:s\ndave:x:30000:y\n",
  model => "Passwd";

transform_test
  name => "remove with partial username",
  yaml => tyaml( ['remove', 'bo', 'carol'] ),
  from => "bob:a:10000:b\ncarol:r:20000:s\n",
  to   => "bob:a:10000:b\n",
  model => "Passwd";

transform_test
  name => "remove with too much of a line given",
  yaml => tyaml( ['remove', 'bob:a:', 'carol'] ),
  from => "bob:a:10000:b\ncarol:r:20000:s\n",
  to   => "bob:a:10000:b\n",
  model => "Passwd";
