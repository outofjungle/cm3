#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 11;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name => "add onto empty",
  yaml => tyaml( 'add bob' ),
  from => "",
  to   => "bob:a:10000:b\n",
  model => "Passwd";

transform_test
  name => "add onto existing",
  yaml => tyaml( 'add carol' ),
  from => "bob:a:10000:b\n",
  to   => "bob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

transform_test
  name => "add when the user already exists",
  yaml => tyaml( 'add carol' ),
  from => "bob:a:10000:b\ncarol:r:20000:s\n",
  to   => "bob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

transform_test
  name => "add when the user already exists with a different line",
  yaml => tyaml( 'add carol' ),
  from => "bob:a:10000:b\ncarol:r:20000:ss\n",
  to   => "bob:a:10000:b\ncarol:r:20000:ss\n",
  model => "Passwd";

transform_test
  name => "add one nonexistent and one good",
  yaml => tyaml( 'add xxx, bob' ),
  from => "",
  to   => "bob:a:10000:b\n",
  model => "Passwd";

transform_test
  name => "add nonexistent",
  yaml => tyaml( 'add xxx' ),
  from => "bob:a:10000:b\n",
  to   => "bob:a:10000:b\n",
  model => "Passwd";

transform_test
  name => "add two at once with commas",
  yaml => tyaml( 'add bob, carol' ),
  from => "",
  to   => "bob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

transform_test
  name => "add two at once with multiple args",
  yaml => tyaml( [ 'add', 'bob', 'carol' ] ),
  from => "",
  to   => "bob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

transform_test
  name => "add mixing commas, multi-arg, and pre-existing users",
  yaml => tyaml( [ 'add', 'bob, nobody7', 'sshd, nobody7, bob, carol' ], 'sortuid' ),
  from => "bob:a:10000:b\ncarol:r:20000:s\n",
  to   => "sshd:x:75:q\nbob:a:10000:b\ncarol:r:20000:s\nnobody7:x:4294967294:z\n",
  model => "Passwd";

transform_test
  name => "add mixing commas, multi-arg, pre-existing users and nonexistent users",
  yaml => tyaml( [ 'add', 'bob, nobody7', 'sshd, nobody2, nobody7, bob, carol' ], 'sortuid' ),
  from => "bob:a:10000:b\ncarol:r:20000:s\n",
  to   => "sshd:x:75:q\nbob:a:10000:b\ncarol:r:20000:s\nnobody7:x:4294967294:z\n",
  model => "Passwd";

transform_test
  name => "two adds in a row",
  yaml => tyaml( 'add dave', [ 'add', 'bob, nobody7', 'sshd, nobody2, nobody7, bob, carol' ], 'sortuid' ),
  from => "bob:a:10000:bx\ncarol:r:20000:s\n",
  to   => "sshd:x:75:q\nbob:a:10000:bx\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  model => "Passwd";
