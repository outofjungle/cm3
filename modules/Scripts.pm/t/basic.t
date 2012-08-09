#!/usr/bin/perl -w

use warnings;
use strict;
use Test::More tests => 7;
# use lib '../../t';
# use zcst qw/:all/;

my $script = "scripts/Scripts.pm";

# load it, make sure it compiles and such
ok( eval { require $script; } );

# import it into some silly package
package scripts_test;
import Scripts qw/:all/;

package main;

can_ok( "scripts_test", "args" );
can_ok( "scripts_test", "get_my_ip" );
can_ok( "scripts_test", "get_hostname" );
can_ok( "scripts_test", "install_file" );
can_ok( "scripts_test", "read_file" );
can_ok( "scripts_test", "write_file" );
