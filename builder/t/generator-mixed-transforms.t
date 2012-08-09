#!/usr/bin/perl

# generator-mixed-transforms.t -- tests generate() when two transform objects with the same name are present

use warnings;
use strict;
use Test::More tests => 1;
use Test::Differences;
use File::Temp qw/tempdir/;
use ChiselTest::Engine;
use YAML::XS ();
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $t_bar = Chisel::Transform->new(
    name => 'func/BAR',
    yaml => "motd:\n- append bar\n",
);

my $t_foo1 = Chisel::Transform->new(
    name => 'func/FOO',
    yaml => "motd:\n- append foo one\n",
);

my $t_foo2 = Chisel::Transform->new(
    name => 'func/FOO',
    yaml => "motd:\n- append foo two\n",
);

my $t_foo3 = Chisel::Transform->new(
    name => 'func/foo',
    yaml => "motd:\n- append foo three\n",
);

my $engine = ChiselTest::Engine->new;
my $generator = $engine->new_generator;

my $result = $generator->generate(
    raws    => [],
    targets => [
        { file => "files/motd/MAIN", transforms => [ $t_bar,  $t_foo1 ] },
        { file => "files/motd/MAIN", transforms => [ $t_bar,  $t_foo2 ] },
        { file => "files/motd/MAIN", transforms => [ $t_bar,  $t_foo3 ] },
        { file => "files/motd/MAIN", transforms => [ $t_foo1, $t_foo2 ] },
        { file => "files/motd/MAIN", transforms => [ $t_foo2, $t_foo3 ] },
        { file => "files/motd/MAIN", transforms => [ $t_foo3, $t_foo1 ] },
    ],
);

eq_or_diff(
    $result,
    [
        { ok => 1, blob => $generator->workspace->git_sha( "blob", "bar\nfoo one\n" ) },
        { ok => 1, blob => $generator->workspace->git_sha( "blob", "bar\nfoo two\n" ) },
        { ok => 1, blob => $generator->workspace->git_sha( "blob", "bar\nfoo three\n" ) },
        { ok => 1, blob => $generator->workspace->git_sha( "blob", "foo one\nfoo two\n" ) },
        { ok => 1, blob => $generator->workspace->git_sha( "blob", "foo two\nfoo three\n" ) },
        { ok => 1, blob => $generator->workspace->git_sha( "blob", "foo three\nfoo one\n" ) },
    ]
);
