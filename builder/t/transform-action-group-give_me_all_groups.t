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
  name => "give_me_all_groups on empty",
  yaml => tyaml( 'give_me_all_groups' ),
  from => "",
  to   => "answersued:*:5554:carol\n1mc-ops:*:5555:dave\nworlds:*:60004:\nApex_DS:*:60005:\nuus_udb_buddylist:*:755685:eddie\n",
  model => "Group";

transform_test
  name => "give_me_all_groups with pre-existing groups and uids",
  yaml => tyaml( 'give_me_all_groups' ),
  from => "xxx:*:1:\nApex_DS:*:755685:\n", # Apex_DS's name and uus_db_buddylists's uid
  to   => "xxx:*:1:\nanswersued:*:5554:carol\n1mc-ops:*:5555:dave\nworlds:*:60004:\nApex_DS:*:755685:\n",
  model => "Group";

transform_test
  name => "give_me_all_groups onto verbatim existing groups",
  yaml => tyaml( 'give_me_all_groups' ),
  from => "answersued:*:5554:carol\n1mc-ops:*:5555:dave\n",
  to   => "answersued:*:5554:carol\n1mc-ops:*:5555:dave\nworlds:*:60004:\nApex_DS:*:60005:\nuus_udb_buddylist:*:755685:eddie\n",
  model => "Group";

transform_test
  name => "give_me_all_groups onto existing groups with different user lists",
  yaml => tyaml( 'give_me_all_groups' ),
  from => "answersued:*:5554:carol\n1mc-ops:*:5555:eddie\n",
  to   => "answersued:*:5554:carol\n1mc-ops:*:5555:eddie,dave\nworlds:*:60004:\nApex_DS:*:60005:\nuus_udb_buddylist:*:755685:eddie\n",
  model => "Group";
