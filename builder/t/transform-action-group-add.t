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
  yaml => tyaml( 'add daemon' ),
  from => "",
  to   => "daemon:*:1:daemon\n",
  model => "Group";

transform_test
  name => "add onto existing",
  yaml => tyaml( 'add Apex_DS' ),
  from => "xxx:*:1:\n",
  to   => "xxx:*:1:\nApex_DS:*:60005:\n",
  model => "Group";

transform_test
  name => "add when the group already exists",
  yaml => tyaml( 'add Apex_DS' ),
  from => "xxx:*:1:\nApex_DS:*:60005:\n",
  to   => "xxx:*:1:\nApex_DS:*:60005:\n",
  model => "Group";

transform_test
  name => "add when the group already exists with different members",
  yaml => tyaml( 'add answersued' ),
  from => "answersued:*:5554:dave\n",
  to   => "answersued:*:5554:dave,carol\n",
  model => "Group";

transform_test
  name => "add when the group already exists with different gid",
  yaml => tyaml( 'add answersued' ),
  from => "answersued:*:5555:dave\n",
  to   => "answersued:*:5555:dave\n",
  model => "Group";

transform_test
  name => "add one nonexistent and one good",
  yaml => tyaml( 'add xxx, answersued' ),
  from => "",
  to   => "answersued:*:5554:carol\n",
  model => "Group";

transform_test
  name => "add nonexistent",
  yaml => tyaml( 'add xxx' ),
  from => "zzz:*:1:\n",
  to   => "zzz:*:1:\n",
  model => "Group";

transform_test
  name => "add two at once with commas",
  yaml => tyaml( 'add answersued, 1mc-ops' ),
  from => "",
  to   => "answersued:*:5554:carol\n1mc-ops:*:5555:dave\n",
  model => "Group";

transform_test
  name => "add two at once with multiple args",
  yaml => tyaml( [ 'add', 'answersued', '1mc-ops' ] ),
  from => "",
  to   => "answersued:*:5554:carol\n1mc-ops:*:5555:dave\n",
  model => "Group";

transform_test
  name => "add mixing commas, multi-arg, and pre-existing groups",
  yaml => tyaml( [ 'add', 'zzz, Apex_DS', 'Apex_DS, answersued' ], 'sortuid' ),
  from => "xxx:*:1:\nApex_DS:*:60005:\n",
  to   => "xxx:*:1:\nanswersued:*:5554:carol\nApex_DS:*:60005:\n",
  model => "Group";

transform_test
  name => "two adds in a row",
  yaml => tyaml( 'add worlds', [ 'add', 'uus_udb_buddylist' ], 'sortuid' ),
  from => "xxx:*:1:\n",
  to   => "xxx:*:1:\nworlds:*:60004:\nuus_udb_buddylist:*:755685:eddie\n",
  model => "Group";
