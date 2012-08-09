#!/usr/bin/perl

# raw-expiration.t -- tests of the expiration code in the raw filesystem

use warnings;
use strict;
use Test::More tests => 4;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use Chisel::Builder::Raw;

Log::Log4perl->init( 't/files/l4p.conf' );

my $raw = Chisel::Builder::Raw->new( now => 1000 )->mount(
    plugin => bless( [], 'FakeRawPlugin' ),
    mountpoint => "/",
);

# our expiration plugin should be OK with no context
eq_or_diff(
    $raw->readraw( 'xxx' ),

    # should yield:
    Chisel::RawFile->new( name => 'xxx', data => 'xxx xxx xxx', ts => 1000 )
);

# context with no timestamp should equal automatic expiration
eq_or_diff(
    $raw->readraw( 'xxx', context => Chisel::RawFile->new( name => 'xxx', data => 'yyy' ) ),

    # should yield:
    Chisel::RawFile->new( name => 'xxx', data => 'xxx xxx xxx', ts => 1000 )
);

# context with a timestamp can still be fresh
eq_or_diff(
    $raw->readraw( 'xxx', context => Chisel::RawFile->new( name => 'xxx', data => 'yyy', ts => 900 ) ),

    # should yield:
    Chisel::RawFile->new( name => 'xxx', data => 'yyy', ts => 900 )
);

# context with a timestamp can have expired (and need a refetch)
eq_or_diff(
    $raw->readraw( 'xxx', context => Chisel::RawFile->new( name => 'xxx', data => 'yyy', ts => 100 ) ),

    # should yield:
    Chisel::RawFile->new( name => 'xxx', data => 'xxx xxx xxx', ts => 1000 )
);

# a plugin that makes use of expiration
package FakeRawPlugin;
use base 'Chisel::Builder::Raw::Base';
sub fetch {
    my ($self, $arg) = @_;
    return "$arg $arg $arg";
}
sub expiration { return 600; }
