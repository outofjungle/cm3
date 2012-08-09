#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 12;
use Test::Differences;
use Test::Exception;
use ChiselTest::Engine;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN {
    use_ok( "Chisel::Metrics" );
};

my $engine = ChiselTest::Engine->new;
my $tempdir  = $engine->config("var");
my $tempfile = "$tempdir/metrics.mdbm";

my $metrics;

ok(
    $metrics = Chisel::Metrics->new(
        application => "test",
        mdbm_file   => $tempfile,
    ),
    "Create metrics object"
);

throws_ok { $metrics->set_metric( {}, "what", "huh") } qr/^Bad metric/, "Bad metric (string)";
throws_ok { $metrics->set( {}, { status_code => "asdf" } ) } qr/^Bad status_code/, "Bad status_code (string)";

ok( $metrics->set_metric( {}, "donkey", 15 ), "Set donkey (15)" );
is( $metrics->get_metric( {}, "donkey" ), 15, "Get donkey (15)" );

ok( $metrics->set_metric( {}, "donkey", 7.7e-05 ), "Set donkey (7.7e-05)" );
is( $metrics->get_metric( {}, "donkey" ), 7.7e-05, "Get donkey (7.7e-05)" );

ok( $metrics->set_metric( {}, "donkey", "0e0" ), "Set donkey (0)" );
is( $metrics->get_metric( {}, "donkey" ), 0, "Get donkey (0)" );

ok( $metrics->set_metric( {}, "donkey", -15 ), "Set donkey (-15)" );
is( $metrics->get_metric( {}, "donkey" ), -15, "Get donkey (-15)" );
