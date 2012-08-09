#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 5;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

transform_test
  name  => "set on blank",
  yaml  => tyaml( 'set vm.swappiness = 80' ),
  from  => "",
  to    => "vm.swappiness = 80\n",
  model => "Sysctl";

transform_test
  name  => "set with replace",
  yaml  => tyaml( 'set vm.swappiness = 80' ),
  from  => "net.ipv4.ip_forward = 0\nvm.swappiness = 0\nnet.ipv4.conf.default.rp_filter = 1\n",
  to    => "net.ipv4.ip_forward = 0\nvm.swappiness = 80\nnet.ipv4.conf.default.rp_filter = 1\n",
  model => "Sysctl";

transform_test
  name  => "set with append",
  yaml  => tyaml( 'set vm.swappiness = 80' ),
  from  => "net.ipv4.ip_forward = 0\nnet.ipv4.conf.default.rp_filter = 1\n",
  to    => "net.ipv4.ip_forward = 0\nnet.ipv4.conf.default.rp_filter = 1\nvm.swappiness = 80\n",
  model => "Sysctl";

transform_test
  name  => "set kernel.core_pattern",
  yaml  => tyaml( 'set kernel.core_pattern = /var/crash/core.%e.%u' ),
  from  => "net.ipv4.ip_forward = 0\nnet.ipv4.conf.default.rp_filter = 1\n",
  to    => "net.ipv4.ip_forward = 0\nnet.ipv4.conf.default.rp_filter = 1\nkernel.core_pattern = /var/crash/core.%e.%u\n",
  model => "Sysctl";

# test invalid sysctl
transform_test
  name   => "invalid sysctl",
  yaml   => tyaml( 'set xxx' ),
  from   => "",
  throws => qr/invalid sysctl/,
  model  => "Sysctl";
