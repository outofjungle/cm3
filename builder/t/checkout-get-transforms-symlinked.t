#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 8;
use Test::Differences;
use Test::Exception;
use ChiselTest::Engine;
use File::Temp qw/tempdir/;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

# make a temp dir to hold transforms
my $tmp = tempdir( CLEANUP => 1 );
mkdir "$tmp/host";

# write one regular file
open my $fh, ">", "$tmp/DEFAULT"
  or die "open: $!\n";
print $fh "motd:\n - append hi\n";
close $fh;

# we'll need this for our eq_or_diff comparisons
my $module_conf = {
    homedir => { model => { MAIN => 'Homedir' } },
    passwd  => {
        default_file => [ 'linux', 'shadow', 'freebsd' ],
        model => { freebsd => 'Passwd', linux => 'Passwd', shadow => 'Passwd' }
    },
};

# test without any symlinks
do {
    my $engine = ChiselTest::Engine->new;
    my $checkout = $engine->new_checkout( transformdir => $tmp );

    eq_or_diff(
        [ sort { "$a" cmp "$b" } $checkout->transforms ],
        [ sort { "$a" cmp "$b" } 
            Chisel::Transform->new( name => 'DEFAULT',      module_conf => $module_conf, yaml => "motd:\n - append hi\n" ),
            Chisel::Transform->new( name => 'DEFAULT_TAIL', module_conf => $module_conf, yaml => "" ),
        ],
        "get transforms without a symlink (baseline)"
    );
};

# make a symlink, try again
unlink "$tmp/host/XXX";
symlink "../DEFAULT", "$tmp/host/XXX" or die "symlink: $!\n";
is( scalar readlink "$tmp/host/XXX", "../DEFAULT" );

do {
    my $engine = ChiselTest::Engine->new;
    my $checkout = $engine->new_checkout( transformdir => $tmp );

    eq_or_diff(
        [ sort { "$a" cmp "$b" } $checkout->transforms ],
        [ sort { "$a" cmp "$b" } 
            Chisel::Transform->new( name => 'DEFAULT',      module_conf => $module_conf, yaml => "motd:\n - append hi\n" ),
            Chisel::Transform->new( name => 'host/XXX',     module_conf => $module_conf, yaml => "motd:\n - append hi\n" ),
            Chisel::Transform->new( name => 'DEFAULT_TAIL', module_conf => $module_conf, yaml => "" ),
        ],
        "get transforms with a symlink"
    );
};

# make a broken symlink, try again
unlink "$tmp/host/XXX";
symlink "../DEFAULTX", "$tmp/host/XXX" or die "symlink: $!\n";
is( scalar readlink "$tmp/host/XXX", "../DEFAULTX" );

do {
    my $engine = ChiselTest::Engine->new;
    my $checkout = $engine->new_checkout( transformdir => $tmp );

    eq_or_diff(
        [ sort { "$a" cmp "$b" } $checkout->transforms ],
        [ sort { "$a" cmp "$b" } 
            Chisel::Transform->new( name => 'DEFAULT',      module_conf => $module_conf, yaml => "motd:\n - append hi\n" ),
            Chisel::Transform->new( name => 'DEFAULT_TAIL', module_conf => $module_conf, yaml => "" ),
        ],
        "get transforms with a broken symlink"
    );
};

# make a malicious symlink, try again
unlink "$tmp/host/XXX";
symlink "/etc/resolv.conf", "$tmp/host/XXX" or die "symlink: $!\n";
is( scalar readlink "$tmp/host/XXX", "/etc/resolv.conf" );

do {
    my $engine = ChiselTest::Engine->new;
    my $checkout = $engine->new_checkout( transformdir => $tmp );

    # try twice, just to make sure
    throws_ok { $checkout->transforms } qr/Transform \[host\/XXX\] cannot be read/, "get transforms with a malicious symlink, try #1";
    throws_ok { $checkout->transforms } qr/Transform \[host\/XXX\] cannot be read/, "get transforms with a malicious symlink, try #2";
};
