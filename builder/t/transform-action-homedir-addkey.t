#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 7;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

my $common_from = <<'EOT';
---
aardvark:
  - "host=\"a.example.com\" ssh-rsa AAAA zorkmid@example.com"
zorkmid:
  - 'ssh-dss AAAA zorkmid@example.com'
EOT

transform_test
  name => "addkey single-arg to existing key",
  yaml => tyaml( 'addkey aardvark rofl' ),
  from => $common_from,
  to   => <<'EOT',
---
aardvark:
  - "host=\"a.example.com\" ssh-rsa AAAA zorkmid@example.com"
  - rofl
zorkmid:
  - 'ssh-dss AAAA zorkmid@example.com'
EOT
  model => 'Homedir';

transform_test
  name => "addkey 4-arg with the same key in both",
  yaml => tyaml( [ 'addkey', 'foo', 'bar', 'foo', 'baz' ] ),
  from => $common_from,
  to   => <<'EOT',
---
aardvark:
  - "host=\"a.example.com\" ssh-rsa AAAA zorkmid@example.com"
foo:
  - bar
  - baz
zorkmid:
  - 'ssh-dss AAAA zorkmid@example.com'
EOT
  model => 'Homedir';

transform_test
  name => "addkey double-arg to new key",
  yaml => tyaml( [ 'addkey', 'foo', ' bar' ] ),
  from => $common_from,
  to   => <<'EOT',
---
aardvark:
  - "host=\"a.example.com\" ssh-rsa AAAA zorkmid@example.com"
foo:
  - ' bar'
zorkmid:
  - 'ssh-dss AAAA zorkmid@example.com'
EOT
  model => 'Homedir';

# try some argument errors
transform_test
  name   => "addkey with zero arguments",
  yaml   => tyaml( 'addkey' ),
  from   => $common_from,
  throws => qr/no arguments in addkey/,
  model  => "Homedir";

transform_test
  name   => "addkey with one argument",
  yaml   => tyaml( 'addkey aardvark' ),
  from   => $common_from,
  throws => qr/could not unpack single argument in addkey/,
  model  => "Homedir";

transform_test
  name   => "addkey with three arguments",
  yaml   => tyaml( [ 'addkey', 'aardvark', 'zorkmid', 'foobar' ] ),
  from   => $common_from,
  throws => qr/odd number of arguments in addkey/,
  model  => "Homedir";

transform_test
  name   => "two addkeys in a row, with one argument each",
  yaml   => tyaml( 'addkey aardvark', 'addkey zorkmid' ),
  from   => $common_from,
  throws => qr/could not unpack single argument in addkey/,
  model  => "Homedir";
