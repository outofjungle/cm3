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
  name  => "add onto empty",
  yaml  => tyaml( 'add bob' ),
  from  => "",
  to    => "bob ALL = (ALL) ALL\n",
  model => "Sudoers";

transform_test
  name  => "add onto existing",
  yaml  => tyaml( 'add bob' ),
  from  => "carol ALL = (ALL) ALL\n",
  to    => "carol ALL = (ALL) ALL\nbob ALL = (ALL) ALL\n",
  model => "Sudoers";

transform_test
  name  => "add when the user already exists",
  yaml  => tyaml( 'add bob' ),
  from  => "bob ALL = (ALL) ALL\n",
  to    => "bob ALL = (ALL) ALL\nbob ALL = (ALL) ALL\n",
  model => "Sudoers";

transform_test
  name => "add mixing commas and multi-arg",
  yaml => tyaml( [ 'add', 'bob, nobody7', 'sshd, nobody7, bob, carol' ] ),
  from => "",
  to   => <<'EOT',
bob ALL = (ALL) ALL
nobody7 ALL = (ALL) ALL
sshd ALL = (ALL) ALL
nobody7 ALL = (ALL) ALL
bob ALL = (ALL) ALL
carol ALL = (ALL) ALL
EOT
  model => "Sudoers";
