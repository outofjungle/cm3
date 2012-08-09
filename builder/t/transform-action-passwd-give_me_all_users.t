#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 6;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name => "give_me_all_users on empty",
  yaml => tyaml( 'give_me_all_users' ),
  from => "",
  to   => "bob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\n",
  model => "Passwd";

transform_test
  name => "give_me_all_users on empty with custom shell",
  yaml => tyaml( 'give_me_all_users shell=/sbin/nologin' ),
  from => "",
  to   => "bob:a:10000:/sbin/nologin\ncarol:r:20000:/sbin/nologin\ndave:x:30000:/sbin/nologin\n",
  model => "Passwd";

transform_test
  name => "give_me_all_users on empty with *bad* custom shell",
  yaml => tyaml( 'give_me_all_users /sbin/nologin' ),
  from => "",
  ret  => undef,
  model => "Passwd";

transform_test
  name => "give_me_all_users with pre-existing users and uids",
  yaml => tyaml( 'give_me_all_users' ),
  from => "carol:r:30000:s\n", # carol's name and dave's uid
  to   => "bob:a:10000:b\ncarol:r:30000:s\n",
  model => "Passwd";

transform_test
  name => "give_me_all_users with pre-existing users and uids, and with custom shell",
  yaml => tyaml( 'give_me_all_users shell=/sbin/nologin' ),
  from => "carol:r:30000:s\n", # carol's name and dave's uid
  to   => "bob:a:10000:/sbin/nologin\ncarol:r:30000:s\n",
  model => "Passwd";

transform_test
  name => "give_me_all_users onto verbatim existing users, with custom shell",
  yaml => tyaml( 'give_me_all_users shell=/sbin/nologin' ),
  from => "bob:a:10000:b\ndave:x:30000:y\n",
  to   => "bob:a:10000:b\ncarol:r:20000:/sbin/nologin\ndave:x:30000:y\n",
  model => "Passwd";
