#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 3;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name  => "truncate on existing",
  yaml  => tyaml( [ 'truncate' ] ),
  from  => "sshd:x:75:q\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  to    => "",
  model => "Passwd";

transform_test
  name  => "truncate on empty",
  yaml  => tyaml( [ 'truncate' ] ),
  from  => "",
  to    => "",
  model => "Passwd";

transform_test
  name  => "truncate followed by append",
  yaml  => tyaml( [ 'truncate' ], [ 'append', 'sshd:x:75:qqq' ] ),
  from  => "sshd:x:75:q\nbob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\nnobody7:x:4294967294:z\n",
  to    => "sshd:x:75:qqq\n",
  model => "Passwd";
