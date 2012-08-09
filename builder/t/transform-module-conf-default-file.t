#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 9;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Transform"); }

# make a basic transform, but add a module.conf
my $t = Chisel::Transform->new(
    name        => 'DEFAULT',
    yaml        => <<'EOT',
motd:
    - append hello world

sudoers:
    - append bob

/files/passwd/MAIN:
    - append MAIN

passwd/MAIN:
    - append MAIN

passwd:
    - add bob
    - add carol

/scripts/passwd:
    - use passwd.1
EOT
    module_conf => {
        motd  => { default_file => [ 'x', 'y' ], },
        passwd => { model => { 'MAIN' => 'Passwd' } },
    },
);

# this one should be a bad transform due to bogus default_file
my $t2 = Chisel::Transform->new(
    name => 'DEFAULT',
    yaml => <<'EOT',
motd:
    - append hello world
EOT
    module_conf => {
        motd  => { default_file => [ '/x', '/y' ], },
        passwd => { model => { 'MAIN' => 'Passwd' } },
    },
);

# load the list of files
eq_or_diff(
    [ sort $t->files ],
    [ qw{ files/motd/x files/motd/y files/passwd/MAIN files/sudoers/MAIN scripts/passwd } ],
    "DEFAULT file list is correct"
);

# load rules for motd/x
my @x_rules = $t->rules( file => "files/motd/x" );
my @y_rules = $t->rules( file => "files/motd/y" );
my @z_rules = $t->rules( file => "files/motd/z" );
my @expected_rules = (
    [ 'append', 'hello world' ],
);

eq_or_diff( \@x_rules, \@expected_rules, "files/motd/x rules are correct" );
eq_or_diff( \@y_rules, \@expected_rules, "files/motd/y rules are correct" );
eq_or_diff( \@z_rules, [], "files/motd/z rules are correct" );

# run transform on motd/x
my $model = Chisel::TransformModel::Text->new;
is( $t->transform( file => "files/motd/x", model => $model ), 1 );
is( $model->text, "hello world\n" );

# run transform on motd/MAIN, which should not exist due to default_file
$model = Chisel::TransformModel::Text->new;
throws_ok { $t->transform( file => "files/motd/MAIN", model => $model ) } qr!asked to transform file \[files/motd/MAIN\] but do not know how!;

# try doing something with the transform that has bogus default_file's
throws_ok { $t2->files } qr!'motd' is a bad file name!, "bogus default_file causes transforms to die";
