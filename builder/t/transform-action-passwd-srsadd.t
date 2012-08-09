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
  name  => "srsadd onto empty",
  yaml  => tyaml( 'srsadd bob' ),
  from  => "",
  to    => "bob:a:10000:b\n",
  model => "Passwd";

transform_test
  name  => "srsadd onto existing",
  yaml  => tyaml( 'srsadd carol' ),
  from  => "bob:a:10000:b\n",
  to    => "bob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

transform_test
  name  => "srsadd when the user already exists",
  yaml  => tyaml( 'srsadd carol' ),
  from  => "bob:a:10000:b\ncarol:r:20000:s\n",
  to    => "bob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

transform_test
  name  => "srsadd when the user already exists with a different line",
  yaml  => tyaml( 'srsadd carol' ),
  from  => "bob:a:10000:b\ncarol:r:20000:ss\n",
  to    => "bob:a:10000:b\ncarol:r:20000:ss\n",
  model => "Passwd";

transform_test
  name  => "srsadd one nonexistent and one good",
  yaml  => tyaml( 'srsadd xxx, bob' ),
  from  => "",
  ret   => undef,
  model => "Passwd";

transform_test
  name  => "srsadd nonexistent",
  yaml  => tyaml( 'srsadd xxx' ),
  from  => "bob:a:10000:b\n",
  ret   => undef,
  model => "Passwd";

transform_test
  name  => "srsadd two at once with commas",
  yaml  => tyaml( 'srsadd bob, carol' ),
  from  => "",
  to    => "bob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

transform_test
  name  => "srsadd two at once with multiple args",
  yaml  => tyaml( [ 'srsadd', 'bob', 'carol' ] ),
  from  => "",
  to    => "bob:a:10000:b\ncarol:r:20000:s\n",
  model => "Passwd";

transform_test
  name  => "srsadd mixing commas, multi-arg, and pre-existing users",
  yaml  => tyaml( [ 'srsadd', 'bob, nobody7', 'sshd, nobody7, bob, carol' ], 'sortuid' ),
  from  => "bob:a:10000:b\ncarol:r:20000:s\n",
  to    => "sshd:x:75:q\nbob:a:10000:b\ncarol:r:20000:s\nnobody7:x:4294967294:z\n",
  model => "Passwd";

transform_test
  name  => "srsadd mixing commas, multi-arg, pre-existing users and nonexistent users",
  yaml  => tyaml( [ 'srsadd', 'bob, nobody7', 'sshd, nobody2, nobody7, bob, carol' ], 'sortuid' ),
  from  => "bob:a:10000:b\ncarol:r:20000:s\n",
  ret   => undef,
  model => "Passwd";

transform_test
  name  => "two srsadds in a row",
  yaml  => tyaml( [ 'add', 'bob, nobody7', 'sshd, nobody7, bob, carol' ], 'add dave', 'sortuid' ),
  from  => "bob:a:10000:b\ncarol:r:20000:s\n",
  to    => "sshd:x:75:q\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  model => "Passwd";
