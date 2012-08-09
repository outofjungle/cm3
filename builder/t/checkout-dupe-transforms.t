#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 7;
use Test::Differences;
use Test::Exception;
use ChiselTest::Engine;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $engine = ChiselTest::Engine->new;
my $tmpdir = $engine->config( "var" );
my $checkout = $engine->new_checkout;

# create a "dupe" transform (different case)
system "cp", "$tmpdir/indir/transforms/func/BAR" => "$tmpdir/indir/transforms/func/foo";

ok( -f "$tmpdir/indir/transforms/func/FOO" );
ok( -f "$tmpdir/indir/transforms/func/foo" );
is( `cat $tmpdir/indir/transforms/func/BAR`, `cat $tmpdir/indir/transforms/func/foo` );
isnt( `cat $tmpdir/indir/transforms/func/FOO`, `cat $tmpdir/indir/transforms/func/foo` );

# should die
throws_ok { $checkout->transforms } qr/Duplicate transform key: func\/foo/i, "builder->transforms detects 'duplicate' transforms";

# twice
throws_ok { $checkout->transforms } qr/Duplicate transform key: func\/foo/i, "builder->transforms detects 'duplicate' transforms the second time";

# cool remove it
unlink "$tmpdir/indir/transforms/func/foo";

# try again
eq_or_diff(
    [ sort map { $_->name } $checkout->transforms ],
    [
        sort 
          'DEFAULT',
          'DEFAULT_TAIL',
          'func/>\'a(b) & c"',
          'func/BADBAD',
          'func/BAR',
          'func/BINARY',
          'func/FOO',
          'func/INVALID',
          'func/MODULE_BUNDLE',
          'func/QUX',
          'func/UNICODE',
          'host/bar1',
          'host/not.a.host',
    ]
);
