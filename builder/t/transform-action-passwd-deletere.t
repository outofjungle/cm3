#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 3;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name  => "deletere from empty",
  yaml  => tyaml( 'deletere bob' ),
  from  => "",
  to    => "",
  model => "Passwd";

transform_test
  name  => "deletere from existing",
  yaml  => tyaml( 'deletere b.b' ),
  from  => "bob:a:10000:b\ncarol:r:20000:s\n",
  to    => "carol:r:20000:s\n",
  model => "Passwd";

transform_test
  name  => "deletere with multiple matches",
  yaml  => tyaml( [ 'deletere', ':.:' ] ),
  from  => "bob:a:10000:b\ncarol:r:20000:s\n",
  to    => "",
  model => "Passwd";
