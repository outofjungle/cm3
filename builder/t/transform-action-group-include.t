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
  yaml  => tyaml( [ 'include', 'group' ] ),
  from  => "",
  to    => <<'EOT',
wheel:*:0:root,bob
daemon:*:1:daemon
kmem:*:2:root
sys:*:3:root
tty:*:4:root
operator:*:5:root,bob
answersued:*:5554:carol
1mc-ops:*:5555:dave
worlds:*:60004:
Apex_DS:*:60005:
uus_udb_buddylist:*:755685:eddie
EOT
  model => "Group";

transform_test
  name  => "include onto existing with additions",
  yaml  => tyaml( [ 'include', 'group' ] ),
  from    => <<'EOT',
daemon:*:1:daemon
kmem:*:2:root
sys:*:3:root
tty:*:4:root
operator:*:5:root,bob
extragroup:*:6:
1mc-ops:*:5555:dave
worlds:*:60004:
Apex_DS:*:60005:
EOT
  to    => <<'EOT',
wheel:*:0:root,bob
daemon:*:1:daemon
kmem:*:2:root
sys:*:3:root
tty:*:4:root
operator:*:5:root,bob
extragroup:*:6:
answersued:*:5554:carol
1mc-ops:*:5555:dave
worlds:*:60004:
Apex_DS:*:60005:
uus_udb_buddylist:*:755685:eddie
EOT
  model => "Group";

transform_test
  name   => "include onto existing with conflicting id",
  yaml   => tyaml( [ 'include', 'group' ] ),
  from    => <<'EOT',
daemon:*:1:daemon
sys:*:3:root
kmem:*:7:
EOT
  throws => qr/'kmem' is already present and cannot be merged/,
  model  => "Group";

transform_test
  name   => "include onto existing with merge of kmem, sys",
  yaml   => tyaml( [ 'include', 'group' ] ),
  from    => <<'EOT',
daemon:*:1:daemon
kmem:*:2:foo,bar
sys:*:3:
worlds:*:60004:baz
EOT
  to    => <<'EOT',
wheel:*:0:root,bob
daemon:*:1:daemon
kmem:*:2:foo,bar,root
sys:*:3:root
tty:*:4:root
operator:*:5:root,bob
answersued:*:5554:carol
1mc-ops:*:5555:dave
worlds:*:60004:baz
Apex_DS:*:60005:
uus_udb_buddylist:*:755685:eddie
EOT
  model  => "Group";

transform_test
  name   => "include of non-group text",
  yaml   => tyaml( [ 'include', 'rawtest' ] ),
  from   => "",
  throws => qr/append of incorrectly formatted text/,
  model  => "Group";
