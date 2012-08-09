#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 5;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

# test invokefor + "add" (it's really common)
transform_test
  name  => "invokefor + add {}",
  yaml  => tyaml( 'invokefor someusers add {}' ),
  from  => "Defaults xxx\n",
  to    => "Defaults xxx\nbob ALL = (ALL) ALL\ncarol ALL = (ALL) ALL\n",
  model => "Sudoers";

transform_test
  name  => "invokefor + add {}, 3-arg",
  yaml  => tyaml( [qw/invokefor someusers add {}/] ),
  from  => "Defaults xxx\n",
  to    => "Defaults xxx\nbob ALL = (ALL) ALL\ncarol ALL = (ALL) ALL\n",
  model => "Sudoers";

transform_test
  name  => "invokefor + add {, }",
  yaml  => tyaml( 'invokefor someusers add {, }' ),
  from  => "Defaults xxx\n",
  to    => "Defaults xxx\nbob ALL = (ALL) ALL\ncarol ALL = (ALL) ALL\n",
  model => "Sudoers";

# test invokefor + "deletere" (also used from time to time)
transform_test
  name  => "invokefor + deletere ^{}",
  yaml  => tyaml( 'invokefor someusers deletere ^{}' ),
  from  => "Defaults xxx\nbob ALL = (ALL) ALL\ncarol ALL = (ALL) ALL\n",
  to    => "Defaults xxx\n",
  model => "Sudoers";

transform_test
  name  => "invokefor + deletere ^{}, 3-arg",
  yaml  => tyaml( [qw/invokefor someusers deletere ^{}/] ),
  from  => "Defaults xxx\nbob ALL = (ALL) ALL\ncarol ALL = (ALL) ALL\n",
  to    => "Defaults xxx\n",
  model => "Sudoers";
