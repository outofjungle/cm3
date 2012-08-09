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
  name  => "replace with regex characters",
  yaml  => tyaml( [ 'replace', 'b.b:', 'bib:' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  model => "Passwd";

transform_test
  name  => "replace with uid change",
  yaml  => tyaml( [ 'replace', 'bob:a:10000:', 'bob:a:99999:' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "carol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\nbob:a:99999:/home/bob:b\n",
  model => "Passwd";

transform_test
  name  => "replace with name change",
  yaml  => tyaml( [ 'replace', 'bob:a:10000:', 'bob2:a:10000:' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "bob2:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  model => "Passwd";

transform_test
  name   => "replace with conflicting name change",
  yaml   => tyaml( [ 'replace', 'bob:a:10000:', 'carol:a:10000:' ] ),
  from   => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  throws => qr/'bob' was transformed into 'carol' which is already present/,
  model  => "Passwd";

transform_test
  name  => "replace multiple lines",
  yaml  => tyaml( [ 'replace', ':/home/', ':/homes/' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "bob:a:10000:/homes/bob:b\ncarol:r:20000:/homes/carolnot:/sbin/nologin\ndave:x:30000:/homes/dave:/sbin/nologin\n",
  model => "Passwd";

transform_test
  name  => "replace 1-arg form",
  yaml  => tyaml( [ 'replace', '20000 20001' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "bob:a:10000:/home/bob:b\ncarol:r:20001:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  model => "Passwd";

transform_test
  name  => "replace 1-arg form with regex characters",
  yaml  => tyaml( [ 'replace', '200.0 20001' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  model => "Passwd";

transform_test
  name  => "replace with too many args",
  yaml  => tyaml( [ 'replace', '1', '2', '3' ] ),
  from  => "",
  ret   => undef,
  model => "Passwd";
