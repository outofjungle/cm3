#!/usr/bin/perl

# builder-stupid-groups.t -- tests the ability of the generator to handle stupid group names
#                            (and checkout and walrus as well... maybe this file should be split)

use warnings;
use strict;
use Test::More tests => 5;
use Test::Differences;
use File::Temp qw/tempdir/;
use ChiselTest::Engine;
use ChiselTest::FakeFunc;
use Log::Log4perl;

# group name we want to be able to handle
my $gname = 'func/>\'a(b) & c"';

# let's see if Checkout can handle it
my $engine = ChiselTest::Engine->new;
my $checkout = $engine->new_checkout( transformdir => "t/files/configs.1/transforms" );
my ( $t ) = grep { $_->name eq $gname } $checkout->transforms;
eq_or_diff(
    $t,
    Chisel::Transform->new(
        name        => $gname,
        yaml        => "motd:\n    - append blah blah\n",
        module_conf => {
            homedir => { model => { 'MAIN' => 'Homedir' } },
            passwd  => {
                default_file => [ 'linux', 'shadow', 'freebsd' ],
                model => { 'linux' => 'Passwd', 'shadow' => 'Passwd', 'freebsd' => 'Passwd' }
            }
        },
    ),
);    # sweet, we got it in $t

# try it in the Walrus
my $walrus = $engine->new_walrus( transforms => [$checkout->transforms], tags => [] );
$walrus->add_host( host => 'abc' );
my @abc_transforms = $walrus->host_transforms( host => 'abc' );
eq_or_diff(
    [ sort map { $_->name } @abc_transforms ],
    [ 'DEFAULT', 'DEFAULT_TAIL', $gname ],
);

# let's see if Transform->order can handle it
my @trs = Chisel::Transform->order( $t, grep { $_->name eq 'DEFAULT' } $checkout->transforms );
eq_or_diff( [ map { $_->id } @trs ], [ 'DEFAULT@05c23445ef27b1dfe3721899b24e91d7df6a1fdc', $t->id ], "Transform->order can handle this group" );

# try it in the Generator
my $generator = $engine->new_generator;

# try to build the motd
my $result = $generator->generate(
    raws    => [ $checkout->raw ],
    targets => [ { transforms => \@trs, file => "files/motd/MAIN" }, ],
);

eq_or_diff(
    $result,
    [ { ok => 1, blob => 'af07222198b163aa2d36abad67333a02f4cd4b58' }, ],
    "generation result is correct"
);

is(
    $generator->workspace->cat_blob( 'af07222198b163aa2d36abad67333a02f4cd4b58' ),
    "hello world\nblah blah\n",
    "generated motd is correct"
);
