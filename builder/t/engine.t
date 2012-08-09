#!/usr/bin/perl

# engine.t -- test basic Engine functions
#             we're NOT using ChiselTest::Engine here so we have more control over the tests

use warnings;
use strict;
use Test::More tests => 15;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN { use_ok("Chisel::Builder::Engine"); }

can_ok("Chisel::Builder::Engine", "new");

# mangle the configfile a bit so it's usable
my $tmp = tempdir( DIRECTORY => '.', CLEANUP => 1 );
my $l4plevel = $ENV{VERBOSE} ? 'TRACE' : 'OFF';
system "cp t/files/builder.conf $tmp/builder.conf";
system "perl -pi -e's!::TMP::!$tmp!g' $tmp/builder.conf";
system "perl -pi -e's!::L4PLEVEL::!$l4plevel!g' $tmp/builder.conf";

# create an empty modules dir (so BStore doesn't freak out that it can't read module.conf's)
mkdir "$tmp/modules";

# same for object workspace
mkdir "$tmp/ws";

# create an engine object
my $engine = Chisel::Builder::Engine->new( configfile => "$tmp/builder.conf" );

isa_ok($engine, "Chisel::Builder::Engine", "Engine object creation");

# should start out non-set-up
ok( !$engine->is_setup, "starts out non-set-up" );

# run setup
is( $engine->setup, $engine, "setup is chainable" );
ok( $engine->is_setup, "is_setup true after running setup" );

# try reading config keys
is( $engine->config( "test" ), "test.value", "'test' config key" );
is( $engine->config( "ssh_user" ), "nobody", "'ssh_user' config key" );
throws_ok { $engine->config( "nonexistent" ) } qr/'nonexistent' does not seem to exist/, "'nonexistent' config key";

# try overriding config keys
my $engine2 = Chisel::Builder::Engine->new( configfile => "$tmp/builder.conf", test => "test.value.different" );
is( $engine2->config( "test" ), "test.value.different", "'test' config key overridden in constructor" );
is( $engine2->config( "ssh_user" ), "nobody", "'ssh_user' config key, again" );

# build various components
isa_ok( $engine->new_actuate,  "Chisel::Builder::Engine::Actuate" );
isa_ok( $engine->new_checkout, "Chisel::Builder::Engine::Checkout" );
isa_ok( $engine->new_walrus( tags => [], transforms => [] ), "Chisel::Builder::Engine::Walrus" );
isa_ok( $engine->new_generator, "Chisel::Builder::Engine::Generator" );
