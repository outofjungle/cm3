#!/usr/bin/perl -w

use warnings;
use strict;
use Test::More tests => 1;

my $script = "scripts/Scripts.pm";

require $script;

# pretty simple test
chomp( my $hostname = `hostname` );
is( Scripts::get_hostname(), $hostname );
