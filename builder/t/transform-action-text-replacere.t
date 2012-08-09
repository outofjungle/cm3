#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 26;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

# these tests are jacked from 'transform-replace.t' but the results are modified
transform_test
  name => "replacere with a regex",
  yaml => tyaml( 'replacere [bd]{3} XX' ),
  from => "aaa\nXXXb\nXXX\nccc\nXXX\neee\n",
  to   => "aaa\nXXXb\nXXX\nccc\nXXX\neee\n";

transform_test
  name => "replacere with a period",
  yaml => tyaml( 'replacere x.z  abc' ),
  from => "xyz = 60\nx.z = 30\n",
  to   => "abc = 60\nabc = 30\n";

transform_test
  name => "replacere with backreferences",
  yaml => tyaml( [ 'replacere', '^([\w\-]+)(:.+:)/home/\\1:/sbin/nologin$', '$1$2/userhome/$1:/sbin/nologin' ] ),
  from => "bob:a:10000:/home/bob:b\ndave:x:30000:/home/dave:/sbin/nologin\ncarol:r:20000:/home/carolnot:/sbin/nologin\n",
  to   => "bob:a:10000:/home/bob:b\ndave:x:30000:/userhome/dave:/sbin/nologin\ncarol:r:20000:/home/carolnot:/sbin/nologin\n";

transform_test
  name => "replacere with a period (2-arg)",
  yaml => tyaml( [ 'replacere', 'x.z', 'abc' ] ),
  from => "xyz = 60\nx.z = 30\n",
  to   => "abc = 60\nabc = 30\n";

transform_test
  name => "replacere with escaped period",
  yaml => tyaml( [ 'replacere', 'x\.z', 'abc' ] ),
  from => "xyz = 60\nx.z = 30\n",
  to   => "xyz = 60\nabc = 30\n";

transform_test
  name => "replacere multiple on a line",
  yaml => tyaml( [ 'replacere', '.', 'x' ] ),
  from => "aaa\n...\n",
  to   => "xxx\nxxx\n";

# make sure POD does not lie
transform_test
  name => "replacere pod example, 1-arg",
  yaml => tyaml( 'replacere foo.bar foo.baz' ),
  from => "xyz foo.baz\nxyz foo.baz\n",
  to   => "xyz foo.baz\nxyz foo.baz\n";

transform_test
  name => "replacere pod example, 2-arg",
  yaml => tyaml( ['replacere', 'foo.bar', 'foo.baz'] ),
  from => "xyz foo.baz\nxyz foo.baz\n",
  to   => "xyz foo.baz\nxyz foo.baz\n";

# extra tests for replacere, not for replace
transform_test
  name => "replacere with lookbehind",
  yaml => tyaml( ['replacere', '(?<=^x.z).*', ' = 45'] ),
  from => "xyz = 60\nx.z = 30\n",
  to   => "xyz = 45\nx.z = 45\n";

transform_test
  name => "replacere with captured variable in \$N-form",
  yaml => tyaml( 'replacere ([bd]{3}) X$1Y' ),
  from => "aaa\nbbbb\nbbb\nccc\nddd\neee\n",
  to   => "aaa\nXbbbYb\nXbbbY\nccc\nXdddY\neee\n";

transform_test
  name => "replacere with captured variable in \${N}-form",
  yaml => tyaml( 'replacere ([bd]{3}) X${1}Y' ),
  from => "aaa\nbbbb\nbbb\nccc\nddd\neee\n",
  to   => "aaa\nXbbbYb\nXbbbY\nccc\nXdddY\neee\n";

transform_test
  name => "replacere with forbidden variable \$0",
  yaml => tyaml( 'replacere ([bd]{3}) X$0Y' ),
  from => "aaa\nbbbb\nbbb\nccc\nddd\neee\n",
  to   => "aaa\nX\$0Yb\nX\$0Y\nccc\nX\$0Y\neee\n";

transform_test
  name => "replacere xxx",
  yaml => tyaml( 'replacere ([bd]{3}) X${0}Y' ),
  from => "aaa\nbbbb\nbbb\nccc\nddd\neee\n",
  to   => "aaa\nX\${0}Yb\nX\${0}Y\nccc\nX\${0}Y\neee\n";

transform_test
  name => "replacere with forbidden variable \$a",
  yaml => tyaml( 'replacere ([bd]{3}) X${0}Y' ),
  from => "aaa\nbbbb\nbbb\nccc\nddd\neee\n",
  to   => "aaa\nX\${0}Yb\nX\${0}Y\nccc\nX\${0}Y\neee\n";

transform_test
  name => "replacere with forbidden variable \${0}",
  yaml => tyaml( 'replacere ([bd]{3}) X$a' ),
  from => "aaa\nbbbb\nbbb\nccc\nddd\neee\n",
  to   => "aaa\nX\$ab\nX\$a\nccc\nX\$a\neee\n";

transform_test
  name => "replacere with variable \$1rofl",
  yaml => tyaml( 'replacere ([bd]{3}) X$1roflY' ),
  from => "aaa\nbbbb\nbbb\nccc\nddd\neee\n",
  to   => "aaa\nXbbbroflYb\nXbbbroflY\nccc\nXdddroflY\neee\n";

transform_test
  name => "replacere with variable \${1rofl}",
  yaml => tyaml( 'replacere ([bd]{3}) X${1rofl}Y' ),
  from => "aaa\nbbbb\nbbb\nccc\nddd\neee\n",
  to   => "aaa\nX\${1rofl}Yb\nX\${1rofl}Y\nccc\nX\${1rofl}Y\neee\n";

transform_test
  name => "replacere with special characters and a captured variable",
  yaml => tyaml( [ 'replacere',  '(.)', '$1""(){}/\\!+*' ] ),
  from => "a\nb\n",
  to   => join( "\n", 'a""(){}/\\!+*', 'b""(){}/\\!+*', '' );

transform_test
  name => "replacere with line beginning marker",
  yaml => tyaml( [ 'replacere', '^x', 'q' ] ),
  from => "axyzf\nxyz\n",
  to   => "axyzf\nqyz\n";

transform_test
  name => "replacere with line ending marker",
  yaml => tyaml( [ 'replacere', 'f$', 'q' ] ),
  from => "axyzf\nxyz\n",
  to   => "axyzq\nxyz\n";

transform_test
  name => "use replacere to double the first character of each line",
  yaml => tyaml( [ 'replacere', '^([ax])', '$1$1' ] ),
  from => "axyzf\nxyz\n",
  to   => "aaxyzf\nxxyz\n";

transform_test
  name => "replacere for long matches",
  yaml => tyaml( [ 'replacere', '^(ab)*', '' ] ),
  from => ( "ab" x 40000 ) . "xxx\n",
  to   => "xxx\n";

transform_test
  name => "replacere likes to add add newlines, it's odd but whatever",
  yaml => tyaml( [ 'replacere', '^xyz', 'XYZ' ] ),
  from => "axyzf\nxyz",
  to   => "axyzf\nXYZ\n";

# test that (?{ code }) is not allowed
transform_test
  name => "replacere does not allow (?{ code })",
  yaml => tyaml( [ 'replacere', '(?{ "foo" })', 'XYZ' ] ),
  from => "foo\nbar\n",
  throws => qr/Eval-group not allowed at runtime/;

# test that (??{ code }) is not allowed
transform_test
  name => "replacere does not allow (??{ code })",
  yaml => tyaml( [ 'replacere', '(??{ "foo" })', 'XYZ' ] ),
  from => "foo\nbar\n",
  throws => qr/Eval-group not allowed at runtime/;

# test that replacere operates on single lines at a time. otherwise things like [^A-Z]+ would match way too much.
transform_test
  name => "replacere should not cross lines",
  yaml => tyaml( [ 'replacere', 'fo[^A-Z]+', 'xxx' ] ),
  from => "foo\nbar\n",
  to   => "xxx\nbar\n";
