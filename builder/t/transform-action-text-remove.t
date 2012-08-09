#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 7;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name => "remove on empty",
  yaml => tyaml( 'remove bbb' ),
  from => "",
  to   => "";

transform_test
  name => "remove simple",
  yaml => tyaml( 'remove bbb' ),
  from => "aaa\nbbb\nccc\nbbb\n",
  to   => "aaa\nccc\n";

transform_test
  name => "remove with colons",
  yaml => tyaml( 'remove bbb' ),
  from => "aaa:\nbbb:\nccc:\nbbb:\n",
  to   => "aaa:\nccc:\n";

transform_test
  name => "remove with partial matches",
  yaml => tyaml( 'remove bb' ),
  from => "aaa\nbbb\nccc\nbbb\n",
  to   => "aaa\nbbb\nccc\nbbb\n";

transform_test
  name => "remove many with commas",
  yaml => tyaml( 'remove aaa, ccc' ),
  from => "aaa\nbbb\nccc\nbbb\n",
  to   => "bbb\nbbb\n";

transform_test
  name => "remove many with multi-arg",
  yaml => tyaml( ['remove', 'aaa', 'ccc'] ),
  from => "aaa\nbbb\nccc\nbbb\n",
  to   => "bbb\nbbb\n";

transform_test
  name => "remove with no args",
  yaml => tyaml( ['remove'] ),
  from => "aaa\nbbb\nccc\nbbb\n",
  to   => "aaa\nbbb\nccc\nbbb\n";
