#!/usr/local/bin/perl -w

use warnings;
use strict;
use Regexp::Chisel qw/ :all /;
use Test::More tests => 282;

# $RE_CHISEL_filepart + $RE_CHISEL_filepart_permissive
do {
    # things that are OK by both strict and permissive
    my @ok_strict = ( "MAIN", "foo", "sshd_config", "Scripts.pm", "foo-bar", ( "X" x 64 ), );

    # things that are OK by permissive, but not by strict
    my @ok_permissive =
      ( "_foo", ".foo", "-foo", " foo", " ", "Scripts;pm", "Scripts pm", ( "X" x 65 ), );

    # things that are not OK by either
    my @no = (
        # just strings of dots
        ".", "..", "...",

        # start with more than one dot
        "..foo",

        # empty string
        "",

        # slashes
        "/", "/foo", "Scripts.pm/", "/Scripts.pm", "Scripts/pm",

        # newline and tab
        "\n", "\t",

        # no full paths...
        "files/hosts.allow/MAIN",
        ".bucket/transforms-index",
        "scripts/hosts.allow",
        "scripts/hosts.allow/",
        "scripts//hosts.allow",
    );

    like( $_, qr/^$RE_CHISEL_filepart\z/, "ok filepart [$_]" ) for( @ok_strict );
    unlike( $_, qr/^$RE_CHISEL_filepart\z/, "no filepart [$_]" ) for( @ok_permissive, @no );

    like( $_, qr/^$RE_CHISEL_filepart_permissive\z/, "ok filepart_permissive [$_]" ) for( @ok_strict, @ok_permissive );
    unlike( $_, qr/^$RE_CHISEL_filepart_permissive\z/, "no filepart_permissive [$_]" ) for @no;
};

# $RE_CHISEL_file + $RE_CHISEL_file_permissive
do {
    # things that are OK by both strict and permissive
    my @ok_strict = ( "files/hosts.allow/MAIN", "scripts/hosts.allow", "scripts/Scripts.pm.asc" );

    # things that are OK by permissive, but not by strict
    my @ok_permissive = (
        "REPO", "MAIN", "sshd_config", "Scripts.pm", "foo-bar", ".foo", ".bucket", ".bucket/transforms-index", ".bucket/ ",
        ( "X" x 1024 )
    );

    # things that are not OK by either
    my @no = (
        # paths that involve just strings of dots
        ".", "..", "...", "files/../MAIN", "/.", "./", "scripts/.", "../transforms-index",

        # paths that start with more than one dot
        "..foo",

        # empty string
        "",

        # leading slashes
        "/", "/foo", "/scripts/Scripts.pm", "/.bucket", "/.bucket/transforms-index",

        # trailing slashes
        "foo/", "scripts/Scripts.pm/", ".bucket/", ".bucket/transforms-index/",

        # doubled slashes in various places
        "/foo/", "scripts//Scripts.pm", ".bucket//", ".bucket//transforms-index",

        # newline and tab
        "\n", "\t",

        # paths too long
        "a/b/c/d/e/f/g", ".a/b/c/d/e/f/g",
    );

    like( $_, qr/^$RE_CHISEL_file\z/, "ok file [$_]" ) for( @ok_strict );
    unlike( $_, qr/^$RE_CHISEL_file\z/, "no file [$_]" ) for( @ok_permissive, @no );

    like( $_, qr/^$RE_CHISEL_file_permissive\z/, "ok file_permissive [$_]" ) for( @ok_strict, @ok_permissive );
    unlike( $_, qr/^$RE_CHISEL_file_permissive\z/, "no file_permissive [$_]" ) for @no;
};

# $RE_CHISEL_raw
do {
    my @ok = ( "FILENAME", "foo/bar", "usergroup/foo.bar-baz qux_rofl", "usergroup/foo:bar:baz", "a/b/c/d/e/f" );
    my @no = ( "", ".", "..", "/foo", "foo//bar", "foo/bar/", "foo/bar ", "foo/ bar", " foo/bar", "usergroup/.foo", "usergroup/foo\nbar", "usergroup/foo\n", "foo\tbar" );
    like( $_, qr/^$RE_CHISEL_raw\z/, "ok raw [$_]" ) for @ok;
    unlike( $_, qr/^$RE_CHISEL_raw\z/, "no raw [$_]" ) for @no;
};

# $RE_CHISEL_tag
do {
    my @ok = ( "GLOBAL", "foo/bar", "property/foo bar", "property/foo.bar", "PROPERTY/foo.bar", "PROPERTY/foo.bar+vault" );
    my @no = ( "global", "foo", "property/foo bar ", "property/ foo.bar", "property/foo:bar", "/bar", " ", "" );
    like( $_, qr/^$RE_CHISEL_tag\z/, "ok tag [$_]" ) for @ok;
    unlike( $_, qr/^$RE_CHISEL_tag\z/, "no tag [$_]" ) for @no;
};

# $RE_CHISEL_tag_type
do {
    my @ok = ( "foo", "property", "PROPERTY" );
    my @no = ( "foo/bar", "foo bar", "foo.bar", "foo/ ", " ", "" );
    like( $_, qr/^$RE_CHISEL_tag_type\z/, "ok tag type [$_]" ) for @ok;
    unlike( $_, qr/^$RE_CHISEL_tag_type\z/, "no tag type [$_]" ) for @no;
};

# $RE_CHISEL_tag_key
do {
    my @ok = ( "bar", "foo bar", "foo.bar" );
    my @no = ( "foo/bar", "foo/bar ", "foo/ ", " ", "", "/", "foo/", "/foo" );
    like( $_, qr/^$RE_CHISEL_tag_key\z/, "ok tag key [$_]" ) for @ok;
    unlike( $_, qr/^$RE_CHISEL_tag_key\z/, "no tag key [$_]" ) for @no;
};

# $RE_CHISEL_hostname
do {
    my @ok = ( "bar", "foo.bar", "foo.bar.foo.com", "m.foo.com", "123.foo.com", "cha102", "m.ya-hoo.com" );
    my @no = ( "foo/bar", "BAR", "Foo.bar", " ", "", "foo dot com", "m.foo.com ", " m.foo.com", ".m.foo.com", "m.foo.com:yroot", "-m.foo.com", "m.-foo.com" );
    like( $_, qr/^$RE_CHISEL_hostname\z/, "ok hostname [$_]" ) for @ok;
    unlike( $_, qr/^$RE_CHISEL_hostname\z/, "no hostname [$_]" ) for @no;
};

# $RE_CHISEL_transform
do {
    my @ok = ( "DEFAULT", "DEFAULT_TAIL", "foo/bar", "f/b", "property/xxx.us", "property/xxx dot us", "property/xxx dot us+vault", 'func/>\'a(b) & c"' );
    my @no = ( "default", "default_tail", "bar", "foo/.bar", "foo/bar\n", "foo/xxx.us ", "foo/ xxx.us", "foo/", "/bar", "/", "" );
    like( $_, qr/^$RE_CHISEL_transform\z/, "ok transform [$_]" ) for @ok;
    unlike( $_, qr/^$RE_CHISEL_transform\z/, "no transform [$_]" ) for @no;
};

# $RE_CHISEL_transform_type
do {
    my @ok = ( "func", "property", "PROPERTY", "role" );
    my @no = ( "property/", " property", " ", " ", " property", " ", "" );
    like( $_, qr/^$RE_CHISEL_transform_type\z/, "ok transform type [$_]" ) for @ok;
    unlike( $_, qr/^$RE_CHISEL_transform_type\z/, "no transform type [$_]" ) for @no;
};

# $RE_CHISEL_transform_key
do {
    my @ok = ( "xxx.us", "xxx dot us", '>\'a(b) & c"', "f oo" );
    my @no = ( ".us", ".svn", '>\'a(b) & c" ', " foo", "foo ", "" );
    like( $_, qr/^$RE_CHISEL_transform_key\z/, "ok transform key [$_]" ) for @ok;
    unlike( $_, qr/^$RE_CHISEL_transform_key\z/, "no transform key [$_]" ) for @no;
};

# $RE_CHISEL_username
do {
    my @ok = ( "fakeuser", "fakeuser1234", "foo", "fakeuser-g", "fakeuser_g", "_dhcp" );
    my @no = ( ".fakeuser", "fakeuser.g", "fakeuser:g", ":fakeuser", "fakeuser:", "fakeuserfakeuserfakeuserfakeuserfakeuser", "foo", "2foo" );
    like( $_, qr/^$RE_CHISEL_username\z/, "ok username [$_]" ) for @ok;
    unlike( $_, qr/^$RE_CHISEL_username\z/, "no username [$_]" ) for @no;
};

# $RE_CHISEL_groupname
do {
    my @ok = ( "fakeuser", "fakeuser1234", "foo", "fakeuser-g", "fakeuser_g", "_dhcp", "foo", "2foo" );
    my @no = ( ".fakeuser", "fakeuser.g", "fakeuser:g", ":fakeuser", "fakeuser:", "fakeuserfakeuserfakeuserfakeuserfakeuser" );
    like( $_, qr/^$RE_CHISEL_groupname\z/, "ok username [$_]" ) for @ok;
    unlike( $_, qr/^$RE_CHISEL_groupname\z/, "no username [$_]" ) for @no;
};
