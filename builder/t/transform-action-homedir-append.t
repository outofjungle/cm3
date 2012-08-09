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
  name  => "append of YAML onto empty",
  yaml  => tyaml( [ 'append', 'foo: [ bar ]' ] ),
  from  => "",
  to    => <<'EOT',
---
foo:
  - bar
EOT
  model => "Homedir";

transform_test
  name  => "append of YAML onto existing",
  yaml  => tyaml( [ 'append', "foo: [ bar2 ]\nbaz2: [qux2]\n" ] ),
  from  => "foo: [ bar ]\nbaz: [ qux ]",
    to    => <<'EOT',
---
baz:
  - qux
baz2:
  - qux2
foo:
  - bar
  - bar2
EOT
  model => "Homedir";

transform_test
  name  => "append of non-YAML onto empty",
  yaml  => tyaml( 'append - roflrofl', 'append roflrofl' ),
  from  => "",
  ret   => undef,
  model => "Homedir";

transform_test
  name  => "append of incompatible YAML onto existing",
  yaml  => tyaml( [ 'append', ' - roflrofl' ] ),
  from  => "foo: [ bar ]",
  ret   => undef,
  model => "Homedir";
