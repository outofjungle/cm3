#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 43;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Transform"); }

# this will be used for a bunch of tests
my $yaml = <<'EOT';
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

# make a basic transform
do {
    my $t = Chisel::Transform->new(
        name        => 'DEFAULT',
        yaml        => $yaml,
        module_conf => { passwd => { model => { 'MAIN' => 'Passwd' } } },
    );

    is( "$t",     'DEFAULT@05c23445ef27b1dfe3721899b24e91d7df6a1fdc', "stringification ok" );
    is( $t->id,   'DEFAULT@05c23445ef27b1dfe3721899b24e91d7df6a1fdc', "identifier ok" );
    is( $t->name, "DEFAULT",                                          "name ok" );
    is( $t->yaml, $yaml,                                              "yaml ok" );
    ok( ! $t->is_loaded, "DEFAULT starts unloaded" );

    # check if it's good, this should load it
    ok( $t->is_good, "DEFAULT is_good" );

    # should be loaded now
    ok( $t->is_loaded, "DEFAULT is loaded after calling files()" );

    # make sure it has no error
    ok( !defined( $t->error ), "DEFAULT has no 'error'" );

    # check does_transform
    ok( $t->does_transform( file => 'files/motd/MAIN' ), "DEFAULT does_transform('files/motd/MAIN')" );
    ok( !$t->does_transform( file => 'bogus' ), "DEFAULT does_transform('bogus')" );

    # check raw_needed
    # (should notice "passwd" because of "add", and "modules/passwd/passwd.1" because of "use passwd.1")
    eq_or_diff( [ "modules/passwd/passwd.1", "passwd" ], [ sort $t->raw_needed ], "DEFAULT raw_needed is correct" );
    eq_or_diff( [ "modules/passwd/passwd.1" ], [ sort $t->raw_needed( file => 'scripts/passwd' ) ], "DEFAULT raw_needed('scripts/passwd') is correct" );
    eq_or_diff( [], [ sort $t->raw_needed( file => 'files/motd/MAIN' ) ], "DEFAULT raw_needed('files/motd/MAIN') is correct" );
    eq_or_diff( [], [ sort $t->raw_needed( file => 'bogus' ) ], "DEFAULT raw_needed('bogus') is correct" );

    # load rules for passwd
    my @passwd_rules = $t->rules( file => "files/passwd/MAIN" );
    my @expected_rules = (
        [ qw/ add bob / ],
        [ qw/ add carol / ],
        [ qw/ append MAIN / ],
        [ qw/ append MAIN / ],
    );

    eq_or_diff( \@passwd_rules, \@expected_rules, "DEFAULT passwd rules are correct" );

    # load rules for bogus file
    my @bogus_rules = $t->rules( file => "bogus" );
    eq_or_diff( \@bogus_rules, [], "DEFAULT bogus rules are correct" );

    # run the transform for motd
    my $model = Chisel::TransformModel::Text->new;
    $t->transform( file => "files/motd/MAIN", model => $model );
    is( $model->text, "hello world\n", "motd file turned out right" );

    # try transforming files we haven't heard of
    throws_ok { $t->transform( file => "/files/motd/MAIN", model => $model ) } qr!asked to transform file \[/files/motd/MAIN\] but do not know how!;
    throws_ok { $t->transform( file => "files/motd", model => $model ) } qr!asked to transform file \[files/motd\] but do not know how!;

    # confirm that the list of files is correct
    eq_or_diff(
        [ sort $t->files ],
        [ qw{ files/motd/MAIN files/passwd/MAIN files/sudoers/MAIN scripts/passwd } ],
        "DEFAULT file list is correct"
    );
};

# try empty yaml to make sure it works
do {
    my $t = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => '',
    );

    eq_or_diff( [ $t->files ], [] );
};

# try a bunch that should fail
do {
    throws_ok {
        my $t = Chisel::Transform->new(
            name => '',
            yaml => $yaml,
        );
    } qr/transform 'name' not given/, "Transform->new requires a name";
};

do {
    my $t = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => "motd: notanarray\n",
    );

    # test stringification
    is( "$t", 'DEFAULT@faa55b164ccc036a5042456eda4471ea4f14173d', "Transform stringification on an object with an error (before is_loaded)" );

    # is_loaded should start off false
    ok( !$t->is_loaded, "Transform->is_loaded false after first stringification" );

    throws_ok { $t->files } qr/rules section is not a key-to-list yaml map/, "Transform->files detects bad rules section";
    throws_ok { $t->files } qr/rules section is not a key-to-list yaml map/, "Transform->files detects bad rules section";

    # error should be set
    is( $t->error, 'DEFAULT@faa55b164ccc036a5042456eda4471ea4f14173d: rules section is not a key-to-list yaml map', "Transform->error returns the correct error" );

    # is_loaded should be yes now
    ok( $t->is_loaded, "Transform->is_loaded true even for a bad transform" );

    # is_good should return 'undef' but *not* die
    is( $t->is_good, undef, "Transform->is_good undef for a bad transform" );

    # stringification should still work after loading
    is( "$t", 'DEFAULT@faa55b164ccc036a5042456eda4471ea4f14173d', "Transform stringification on an object with an error (after is_loaded)" );
};

do {
    my $t = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => "$yaml\nasdfasdf",
    );

    throws_ok { $t->files } qr/YAML::XS::Load Error/, "Transform->files detects bad YAML";
    throws_ok { $t->files } qr/YAML::XS::Load Error/, "Transform->files detects bad YAML a second time";

    # error should be set
    like( $t->error, qr/YAML::XS::Load Error/, "Transform->error returns the correct error" );

    # is_loaded should be yes now
    ok( $t->is_loaded, "Transform->is_loaded true even for a bad transform" );

    # is_good should return 'undef' but *not* die
    is( $t->is_good, undef, "Transform->is_good undef for a bad transform" );
};

do {
    my $t = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => "passwd:\n - foo\n",
    );

    throws_ok { $t->files } qr/'foo' is not a valid action/, "Transform->files detects bad actions";
    throws_ok { $t->files } qr/'foo' is not a valid action/, "Transform->files detects bad actions a second time";

    is( $t->error, "'foo' is not a valid action", "Transform->error returns the correct error" );
};

do {
    my $t = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => "\"passwd/.dot\":\n - nop\n",
    );

    throws_ok { $t->files } qr/'passwd\/.dot' is a bad file name/, "Transform->files detects bad file names";
    throws_ok { $t->files } qr/'passwd\/.dot' is a bad file name/, "Transform->files detects bad file names a second time";
};

do {
    my $t = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => "\"/passwd/linux\":\n - nop\n",
    );

    throws_ok { $t->files } qr/'\/passwd\/linux' is a bad file name/, "Transform->files detects bad file names when leading / is used to disable munging";
    throws_ok { $t->files } qr/'\/passwd\/linux' is a bad file name/, "Transform->files detects bad file names when leading / is used to disable munging, a second time";
};
