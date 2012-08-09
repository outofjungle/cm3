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
  name => "replace with a regex",
  yaml => tyaml( 'replace [bd]{3} XX' ),
  from => "aaa\nbbbb\nbbb\nccc\nddd\neee\n",
  to   => "aaa\nbbbb\nbbb\nccc\nddd\neee\n";

transform_test
  name => "replace with a period",
  yaml => tyaml( 'replace x.z  abc' ),
  from => "xyz = 60\nx.z = 30\n",
  to   => "xyz = 60\nabc = 30\n";

transform_test
  name => "replace with a period (2-arg)",
  yaml => tyaml( [ 'replace', 'x.z', 'abc' ] ),
  from => "xyz = 60\nx.z = 30\n",
  to   => "xyz = 60\nabc = 30\n";

transform_test
  name => "replace with escaped period",
  yaml => tyaml( [ 'replace', 'x\.z', 'abc' ] ),
  from => "xyz = 60\nx.z = 30\n",
  to   => "xyz = 60\nx.z = 30\n";

transform_test
  name => "replace multiple on a line",
  yaml => tyaml( [ 'replace', '.', 'x' ] ),
  from => "aaa\n...\n",
  to   => "aaa\nxxx\n";

transform_test
  name => "replace with too many args",
  yaml => tyaml( [ 'replace', '.', 'x', 'y' ] ),
  from => "aaa\n...\n",
  ret  => undef;

# make sure POD does not lie
transform_test
  name => "replace pod example, 1-arg",
  yaml => tyaml( 'replace foo.bar foo.baz' ),
  from => "xyz fooxbar\nxyz foo.bar\n",
  to   => "xyz fooxbar\nxyz foo.baz\n";

transform_test
  name => "replace pod example, 2-arg",
  yaml => tyaml( ['replace', 'foo.bar', 'foo.baz'] ),
  from => "xyz fooxbar\nxyz foo.bar\n",
  to   => "xyz fooxbar\nxyz foo.baz\n";
