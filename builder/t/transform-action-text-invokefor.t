#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 16;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

# simple stuff
transform_test
  name => "invokefor without replacement",
  yaml => tyaml( 'invokefor func/bbb01-03 append aaa ccc' ),
  from => "",
  to   => "aaa ccc\n";

transform_test
  name => "invokefor onto empty",
  yaml => tyaml( 'invokefor func/bbb01-03 append aaa {} ccc' ),
  from => "",
  to   => "aaa bbb01 ccc\naaa bbb02 ccc\naaa bbb03 ccc\n";

transform_test
  name => "invokefor onto existing",
  yaml => tyaml( 'invokefor func/bbb01-03 prepend aaa {} ccc' ),
  from => "foo\n",
  to   => "aaa bbb03 ccc\naaa bbb02 ccc\naaa bbb01 ccc\nfoo\n";

transform_test
  name => "invokefor with two sets of curly braces",
  yaml => tyaml( 'invokefor func/bbb01-03 append aaa {} ccc {,}' ),
  from => "foo\n",
  to   => "foo\naaa bbb01 ccc {,}\naaa bbb02 ccc {,}\naaa bbb03 ccc {,}\n";

transform_test
  name => "invokefor with delimiters",
  yaml => tyaml( 'invokefor func/bbb01-03 append aaa {::} ccc' ),
  from => "foo\n",
  to   => "foo\naaa bbb01::bbb02::bbb03 ccc\n";

transform_test
  name => "invokefor with empty range",
  yaml => tyaml( 'invokefor func/empty() append aaa {} ccc' ),
  from => "foo\n",
  to   => "foo\n";

transform_test
  name => "invokefor with empty range and delimiter",
  yaml => tyaml( 'invokefor func/empty() append aaa {,} ccc' ),
  from => "foo\n",
  to   => "foo\n";

# test the 3-arg form
transform_test
  name   => "3-arg invokefor",
  yaml   => tyaml( [ 'invokefor', "func/bbb01-03", "append", "aa {}" ] ),
  from   => "foo\n",
  to     => "foo\naa bbb01\naa bbb02\naa bbb03\n";

transform_test
  name   => "3-arg invokefor with a stupid group name",
  yaml   => tyaml( [ 'invokefor', q!func/>'a(b) & c"!, "append", "{}" ] ),
  from   => "foo\n",
  to     => "foo\nabc\ndef\n";

# test stacking two invokefors
transform_test
  name   => "3-arg invokefor",
  yaml   => tyaml( 'invokefor func/bbb01-03 append aaa {::} ccc', 'invokefor func/bbb01-03 append ddd {::} eee' ),
  from   => "foo\n",
  to     => "foo\naaa bbb01::bbb02::bbb03 ccc\nddd bbb01::bbb02::bbb03 eee\n";

# test some errors
transform_test
  name   => "invokefor with no args",
  yaml   => tyaml( 'invokefor' ),
  from   => "foo\n",
  ret    => undef;

transform_test
  name   => "invokefor with one arg",
  yaml   => tyaml( 'invokefor someusers' ),
  from   => "foo\n",
  ret    => undef;

transform_test
  name   => "invokefor with two args (nop)",
  yaml   => tyaml( 'invokefor someusers nop' ),
  from   => "foo\n",
  to     => "foo\n";

transform_test
  name   => "invokefor with two args (truncate)",
  yaml   => tyaml( 'invokefor someusers truncate' ),
  from   => "foo\n",
  to     => "";

transform_test
  name   => "invokefor with a range error",
  yaml   => tyaml( 'invokefor range_error_please() append aaa {,} ccc' ),
  from   => "foo\n",
  throws => qr/range error/;

transform_test
  name   => "invokefor with a nonexistent action",
  yaml   => tyaml( 'invokefor func/bbb01-03 no_command_exists aaa {} ccc' ),
  from   => "foo\n",
  ret    => undef;
