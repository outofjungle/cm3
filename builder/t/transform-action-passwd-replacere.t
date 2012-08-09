#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 9;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name  => "replacere with backreferences",
  yaml  => tyaml( [ 'replacere', '^([\w\-]+)(:.+:)/home/\\1:/sbin/nologin$', '$1$2/userhome/$1:/sbin/nologin' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/userhome/dave:/sbin/nologin\n",
  model => "Passwd";

transform_test
  name  => "replacere with uid change",
  yaml  => tyaml( [ 'replacere', '^bob:a:10000:', 'bob:a:99999:' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "carol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\nbob:a:99999:/home/bob:b\n",
  model => "Passwd";

transform_test
  name  => "replacere with name change",
  yaml  => tyaml( [ 'replacere', '^bob:a:10000:', 'bob2:a:10000:' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "bob2:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  model => "Passwd";

transform_test
  name   => "replacere with conflicting name change",
  yaml   => tyaml( [ 'replacere', '^bob:a:10000:', 'carol:a:10000:' ] ),
  from   => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  throws => qr/'bob' was transformed into 'carol' which is already present/,
  model  => "Passwd";

transform_test
  name  => "replacere 1-arg form",
  yaml  => tyaml( [ 'replacere', '20000 20001' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "bob:a:10000:/home/bob:b\ncarol:r:20001:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  model => "Passwd";

transform_test
  name  => "replace 1-arg form with regex characters",
  yaml  => tyaml( [ 'replacere', '200.0 20001' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "bob:a:10000:/home/bob:b\ncarol:r:20001:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  model => "Passwd";

transform_test
  name  => "replace into comment",
  yaml  => tyaml( [ 'replacere', 'carol.*', '#car' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "bob:a:10000:/home/bob:b\ndave:x:30000:/home/dave:/sbin/nologin\n",
  model => "Passwd";

transform_test
  name  => "replace into blank line",
  yaml  => tyaml( [ 'replacere', 'carol.*', '' ] ),
  from  => "bob:a:10000:/home/bob:b\ncarol:r:20000:/home/carolnot:/sbin/nologin\ndave:x:30000:/home/dave:/sbin/nologin\n",
  to    => "bob:a:10000:/home/bob:b\ndave:x:30000:/home/dave:/sbin/nologin\n",
  model => "Passwd";

transform_test
  name  => "replacere with too many args",
  yaml  => tyaml( [ 'replacere', '1', '2', '3' ] ),
  from  => "",
  ret   => undef,
  model => "Passwd";
