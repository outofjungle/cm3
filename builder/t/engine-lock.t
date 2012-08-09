#!/usr/bin/perl

# engine1-lock.t -- test Engine locking functions

use warnings;
use strict;
use Test::More tests => 8;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Chisel::Builder::Engine;

# mangle the configfile a bit so it's usable
my $tmp = tempdir( DIRECTORY => '.', CLEANUP => 1 );
my $l4plevel = $ENV{VERBOSE} ? 'TRACE' : 'OFF';
system "cp t/files/builder.conf $tmp/builder.conf";
system "perl -pi -e's!::TMP::!$tmp!g' $tmp/builder.conf";
system "perl -pi -e's!::L4PLEVEL::!$l4plevel!g' $tmp/builder.conf";

# create an empty lock dir (Engine doesn't create it on its own)
mkdir "$tmp/lock";

# create two engine objects
my $engine1 = Chisel::Builder::Engine->new( configfile => "$tmp/builder.conf" )->setup;
my $engine2 = Chisel::Builder::Engine->new( configfile => "$tmp/builder.conf" )->setup;

# test non-blocking locks
do {
    # get a lock on 'foo' with engine1
    my $foolock = $engine1->lock( 'foo' );

    # should be impossible to lock 'foo' again, even by another engine
    throws_ok { $engine1->lock( 'foo' ) } qr/Resource temporarily unavailable/, "foo cannot be locked twice by the same engine";
    throws_ok { $engine2->lock( 'foo' ) } qr/Resource temporarily unavailable/, "foo cannot be locked twice by different engines";

    # the other engine should be able to lock 'bar' though
    my $barlock = $engine2->lock( 'bar' );

    # let's try releasing one of the locks and reacquiring it with a different engine
    undef $foolock;
    ok( $foolock = $engine2->lock( 'foo' ), "foo can be locked again after being released" );

    # now the original engine shouldn't be able to get it
    throws_ok { $engine1->lock( 'foo' ) } qr/Resource temporarily unavailable/, "foo cannot be locked twice";
};

# test blocking locks
do {
    # get a lock on 'foo' with engine1
    my $foolock = $engine1->lock( 'foo' );

    # try to get a blocking lock on 'foo' with a different engine
    eval {
        local $SIG{'ALRM'} = sub { die "alarmed!" };
        alarm 2;
        $engine2->lock( 'foo', block => 1 );
    };

    like( $@, qr/alarmed!/, "blocking lock times out" );

    # try a non-blocking lock
    throws_ok { $engine1->lock( 'foo' ) } qr/Resource temporarily unavailable/, "foo cannot be locked twice by the same engine";
    throws_ok { $engine2->lock( 'foo' ) } qr/Resource temporarily unavailable/, "foo cannot be locked twice by different engines";

    # try a blocking lock on a different file
    my $barlock = $engine1->lock( 'bar', block => 1 );
    throws_ok { $engine1->lock( 'bar' ) } qr/Resource temporarily unavailable/, "lock on 'bar' was acquired";
};
