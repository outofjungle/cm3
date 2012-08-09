#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 4;
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
  name => "clearkey on existing key",
  yaml => tyaml( 'clearkey aardvark' ),
  from => $common_from,
  to   => <<'EOT',
---
zorkmid:
  - 'ssh-dss AAAA zorkmid@example.com'
EOT
  model => 'Homedir';

transform_test
  name => "clearkey on nonexistent key",
  yaml => tyaml( 'clearkey foo' ),
  from => $common_from,
  to   => <<'EOT',
---
aardvark:
  - "host=\"a.example.com\" ssh-rsa AAAA zorkmid@example.com"
zorkmid:
  - 'ssh-dss AAAA zorkmid@example.com'
EOT
  model => 'Homedir';

transform_test
  name => "clearkey with multiple args",
  yaml => tyaml( ['clearkey', 'aardvark', 'foo', 'zorkmid'] ),
  from => $common_from,
  to   => "--- {}\n",
  model => 'Homedir';

# try some argument errors
transform_test
  name   => "clearkey with zero arguments",
  yaml   => tyaml( 'clearkey' ),
  from   => $common_from,
  throws => qr/no arguments in clearkey/,
  model => 'Homedir';
