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
  name  => "use onto empty",
  yaml  => tyaml( [ 'use', 'passwd' ] ),
  from  => "",
  to    => "sshd:x:75:q\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  model => "Passwd";

transform_test
  name  => "use onto existing with additions",
  yaml  => tyaml( [ 'use', 'passwd' ] ),
  from  => "root:x:0:r\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  to    => "sshd:x:75:q\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  model => "Passwd";

transform_test
  name  => "use onto existing with conflicts",
  yaml  => tyaml( [ 'use', 'passwd' ] ),
  from  => "sshd:x:0:r\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  to    => "sshd:x:75:q\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  model => "Passwd";

transform_test
  name   => "use of non-passwd text",
  yaml   => tyaml( [ 'use', 'rawtest' ] ),
  from   => "",
  throws => qr/append of incorrectly formatted text/,
  model  => "Passwd";
