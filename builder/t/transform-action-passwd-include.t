#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 5;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name  => "include onto empty",
  yaml  => tyaml( [ 'include', 'passwd' ] ),
  from  => "",
  to    => "sshd:x:75:q\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  model => "Passwd";

transform_test
  name  => "include onto existing with additions",
  yaml  => tyaml( [ 'include', 'passwd' ] ),
  from  => "root:x:0:r\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  to    => "root:x:0:r\nsshd:x:75:q\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  model => "Passwd";

transform_test
  name   => "include onto existing with conflicting id",
  yaml   => tyaml( [ 'include', 'passwd' ] ),
  from   => "sshd:x:0:r\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  throws => qr/'sshd' is already present and cannot be merged/,
  model  => "Passwd";

transform_test
  name   => "include onto existing with merge conflict",
  yaml   => tyaml( [ 'include', 'passwd' ] ),
  from   => "sshd:x:75:rr\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  throws => qr/'sshd' is already present and cannot be merged/,
  model  => "Passwd";

transform_test
  name   => "include of non-passwd text",
  yaml   => tyaml( [ 'include', 'rawtest' ] ),
  from   => "",
  throws => qr/append of incorrectly formatted text/,
  model  => "Passwd";
