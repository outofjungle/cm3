#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 5;
use Test::Differences;
use Test::Exception;
use ChiselTest::Engine;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $engine = ChiselTest::Engine->new;
my $tmpdir = $engine->config( "var" );
my $checkout = $engine->new_checkout;

# create a "dupe" tag (different case)
system "cp", "$tmpdir/indir/tags/notag" => "$tmpdir/indir/tags/NOTAG";

ok( -f "$tmpdir/indir/tags/notag" );
ok( -f "$tmpdir/indir/tags/NOTAG" );
is( `cat $tmpdir/indir/tags/notag`, `cat $tmpdir/indir/tags/NOTAG` );

# should die
throws_ok { $checkout->tags } qr{Duplicate tag keys: (cmdb_property/NOTAG, cmdb_property/notag|cmdb_property/notag, cmdb_property/NOTAG)}, "builder->tags detects 'duplicate' tags";

# cool remove it
unlink "$tmpdir/indir/tags/NOTAG";

# try again
eq_or_diff( [ map {"$_"} $checkout->tags], ['cmdb_property/notag'] );
