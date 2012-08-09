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
  name => "chsh on empty",
  yaml => tyaml( 'chsh bob /bin/bash' ),
  from => "",
  to   => "",
  model => "Passwd";

transform_test
  name => "chsh on an existing user (1-arg)",
  yaml => tyaml( 'add bob, carol, dave', 'chsh carol /bin/bash' ),
  from => "",
  to   => "bob:a:10000:b\ncarol:r:20000:/bin/bash\ndave:x:30000:y\n",
  model => "Passwd";

transform_test
  name => "chsh on a nonexistent user (1-arg)",
  yaml => tyaml( 'add bob, carol, dave', 'chsh ccarol /bin/bash' ),
  from => "",
  to   => "bob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\n",
  model => "Passwd";

transform_test
  name => "chsh on an existing user (2-arg)",
  yaml => tyaml( 'add bob, carol, dave', ['chsh', 'carol', '/bin/bash'] ),
  from => "",
  to   => "bob:a:10000:b\ncarol:r:20000:/bin/bash\ndave:x:30000:y\n",
  model => "Passwd";

transform_test
  name => "chsh on a nonexistent user (2-arg)",
  yaml => tyaml( 'add bob, carol, dave', ['chsh', 'ccarol', '/bin/bash'] ),
  from => "",
  to   => "bob:a:10000:b\ncarol:r:20000:s\ndave:x:30000:y\n",
  model => "Passwd";

transform_test
  name => "chsh with bad shell",
  yaml => tyaml( 'chsh bob /bin/' ),
  from => "bob:a:1:b\ncarol:r:2:s\n",
  ret  => undef,
  model => "Passwd";

transform_test
  name => "chsh with no shell",
  yaml => tyaml( 'chsh bob' ),
  from => "bob:a:1:b\ncarol:r:2:s\n",
  ret  => undef,
  model => "Passwd";

transform_test
  name => "chsh with no args",
  yaml => tyaml( 'chsh' ),
  from => "bob:a:1:b\ncarol:r:2:s\n",
  ret  => undef,
  model => "Passwd";
