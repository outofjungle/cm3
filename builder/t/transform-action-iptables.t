#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 18;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

my $preamble = <<'EOT';
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:DUMP - [0:0]
EOT

transform_test
  name   => "accept",
  yaml   => tyaml( 'accept' ),
  throws => qr/Invalid iptables rule/,
  model  => "Iptables";

transform_test
  name  => "accept any",
  yaml  => tyaml( 'accept any' ),
  to    => "${preamble}-A INPUT -j ACCEPT\n",
  model => "Iptables";

transform_test
  name  => "accept ip",
  yaml  => tyaml( 'accept ip 1.1.1.1' ),
  to    => "${preamble}-A INPUT -s 1.1.1.1/32 -j ACCEPT\n",
  model => "Iptables";

transform_test
  name  => "accept cidr",
  yaml  => tyaml( 'accept ip 1.1.1.1/24' ),
  to    => "${preamble}-A INPUT -s 1.1.1.1/24 -j ACCEPT\n",
  model => "Iptables";

transform_test
  name  => "accept host",
  yaml  => tyaml( 'accept host foo.fake-domain.com' ),
  to    => "${preamble}-A INPUT -s 10.0.0.1/32 -j ACCEPT\n",
  model => "Iptables";

transform_test
  name  => "accept host + port",
  yaml  => tyaml( 'accept host foo.fake-domain.com port 4443/tcp' ),
  to    => "${preamble}-A INPUT -s 10.0.0.1/32 -p tcp -m tcp --dport 4443 -j ACCEPT\n",
  model => "Iptables";

transform_test
  name  => "accept role",
  yaml  => tyaml( 'accept role foo.bar port 4443/tcp' ),
  to    => $preamble 
               . "-A INPUT -s 10.1.0.1/32 -p tcp -m tcp --dport 4443 -j ACCEPT\n"
               . "-A INPUT -s 10.1.0.2/32 -p tcp -m tcp --dport 4443 -j ACCEPT\n",
  model => "Iptables";

transform_test
  name  => "accept empty role",
  yaml  => tyaml( 'accept role foo.baz port 4443/tcp' ),
  to    => $preamble,
  model => "Iptables";

transform_test
  name  => "multiple rules",
  yaml  => tyaml('accept host foo.fake-domain.com port 4443/tcp',
                 'accept role foo.bar port 53/udp',
                 'accept host baz.fake-domain.com port 4443/tcp',
                 'drop port 4443/tcp',
                 'reject port 443/tcp'),
  to    => $preamble
               . "-A INPUT -s 10.0.0.1/32 -p tcp -m tcp --dport 4443 -j ACCEPT\n"
               . "-A INPUT -s 10.1.0.1/32 -p udp -m udp --dport 53 -j ACCEPT\n"
               . "-A INPUT -s 10.1.0.2/32 -p udp -m udp --dport 53 -j ACCEPT\n"
               . "-A INPUT -s 10.0.0.3/32 -p tcp -m tcp --dport 4443 -j ACCEPT\n"
               . "-A INPUT -p tcp -m tcp --dport 4443 -j DROP\n"
               . "-A INPUT -p tcp -m tcp --dport 443 -j REJECT --reject-with icmp-port-unreachable\n",
  model => "Iptables";

# test noexclude
transform_test
  name   => "unresolvable hostname",
  yaml   => tyaml( 'accept host bar.fake-domain.com' ),
  to     => $preamble,
  model  => "Iptables";

transform_test
  name   => "role with unresolvable name",
  yaml   => tyaml( 'accept role foo.qux' ),
  to    => $preamble
               . "-A INPUT -s 10.1.0.1/32 -j ACCEPT\n"
               . "-A INPUT -s 10.1.0.2/32 -j ACCEPT\n",
  model  => "Iptables";

transform_test
  name   => "unresolvable hostname + noexclude",
  yaml   => tyaml( 'accept host bar.fake-domain.com noexclude' ),
  throws => qr/Unresolvable hostname/,
  model  => "Iptables";

transform_test
  name   => "role with unresolvable name + noexclude",
  yaml   => tyaml( 'accept role foo.qux noexclude' ),
  throws => qr/Unresolvable hostname in role/,
  model  => "Iptables";

transform_test
  name   => "role with all resolvable names + noexclude",
  yaml   => tyaml( 'accept role foo.bar noexclude' ),
  to    => $preamble
               . "-A INPUT -s 10.1.0.1/32 -j ACCEPT\n"
               . "-A INPUT -s 10.1.0.2/32 -j ACCEPT\n",
  model  => "Iptables";

# test some errors
transform_test
  name   => "invalid ip",
  yaml   => tyaml( 'accept ip foo.fake-domain.com' ),
  throws => qr/Invalid iptables rule/,
  model  => "Iptables";

transform_test
  name   => "invalid port spec",
  yaml   => tyaml( 'accept host foo.fake-domain.com port 4443' ),
  throws => qr/Invalid iptables rule/,
  model  => "Iptables";

transform_test
  name   => "invalid args",
  yaml   => tyaml( 'accept host foo.fake-domain.com blah' ),
  throws => qr/Invalid iptables rule/,
  model  => "Iptables";

transform_test
  name   => "invalid args 2",
  yaml   => tyaml( 'accept host' ),
  throws => qr/Invalid iptables rule/,
  model  => "Iptables";
