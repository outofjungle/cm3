#!/var/chisel/bin/perl -w

use warnings;
use strict;
use File::Temp qw/tempdir/;
use Test::More tests => 2;

ok( -x "/var/chisel/bin/chisel_get_transport", "chisel_get_transport exists");
ok( -x "/var/chisel/bin/chisel_client_sync", "chisel_client_sync exists");
