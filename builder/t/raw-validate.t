#!/usr/bin/perl

# raw-validate.t -- tests of the validation code in the raw filesystem

use warnings;
use strict;
use Test::More tests => 7;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use Chisel::Builder::Raw;

Log::Log4perl->init( 't/files/l4p.conf' );

my $raw = Chisel::Builder::Raw->new( now => 0 )->mount(
    plugin => bless( [], 'FakeRawPlugin' ),
    mountpoint => "/foo",
);

# test with name xxx
do {
    # expected result if validation succeeds
    my $rf_xxx = Chisel::RawFile->new( name => 'foo/xxx', data => 'xxx xxx xxx' );

    # should be OK with no context
    eq_or_diff( $raw->readraw( 'foo/xxx' ), $rf_xxx );

    # if it has context, should require 'goody'
    eq_or_diff( $raw->readraw( 'foo/xxx', context => Chisel::RawFile->new( name => 'foo/xxx', data => 'goody' ) ), $rf_xxx );
    eq_or_diff( $raw->readraw( 'foo/xxx', context => Chisel::RawFile->new( name => 'foo/xxx', data => 'baddy' ) ),
        Chisel::RawFile->new( name => 'foo/xxx', data => 'baddy', data_pending => 'xxx xxx xxx' ) );
};

# test with name yyy
do {
    # expected result if validation succeeds
    my $rf_yyy = Chisel::RawFile->new( name => 'foo/yyy', data => 'yyy yyy yyy' );

    # should return data = undef with no context
    eq_or_diff( $raw->readraw( 'foo/yyy' ),
        Chisel::RawFile->new( name => 'foo/yyy', data => undef, data_pending => 'yyy yyy yyy' ) );

    # if it has context, should require 'prevy'
    eq_or_diff( $raw->readraw( 'foo/yyy', context => Chisel::RawFile->new( name => 'foo/yyy', data => 'prevy' ) ), $rf_yyy );
    eq_or_diff( $raw->readraw( 'foo/yyy', context => Chisel::RawFile->new( name => 'foo/yyy', data => 'goody' ) ),
        Chisel::RawFile->new( name => 'foo/yyy', data => 'goody', data_pending => 'yyy yyy yyy' ) );
};

# test with name zzz
do {
    # should die on validation
    eq_or_diff( $raw->readraw( 'foo/zzz' ),
        Chisel::RawFile->new( name => 'foo/zzz', data => undef, data_pending => 'zzz zzz zzz' ) );
};

# a plugin that makes use of validation
package FakeRawPlugin;
use base 'Chisel::Builder::Raw::Base';
sub fetch {
    my ($self, $arg) = @_;
    return "$arg $arg $arg";
}
sub validate {
    my ( $self, $key, $new, $old ) = @_;
    if( $key eq 'yyy' ) {
        # context is required, and must be 'prevy'
        return defined $old && $old eq 'prevy';
    } elsif( $key eq 'zzz' ) {
        # just die, to make sure this is ok
        die "ZZZ DEAD\n";
    } else {
        # context not required, but if it exists it must be 'goody'
        return ! defined $old || $old eq 'goody';
    }
}
