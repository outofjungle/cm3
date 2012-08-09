#!/usr/bin/perl

# raw-fetch.t -- tests of the fetch code in the raw filesystem

use warnings;
use strict;
use Test::More tests => 18;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use Chisel::Builder::Raw;

Log::Log4perl->init( 't/files/l4p.conf' );

my $raw = Chisel::Builder::Raw->new( now => 0 )->mount(
    plugin => bless( [], 'FakeRawPlugin' ),
    mountpoint => "/foo",
);

# with validation OK, data should equal whatever fetch returns
eq_or_diff( $raw->readraw( 'foo/fokvok' ), Chisel::RawFile->new( name => 'foo/fokvok', data => 'xxx' ) );
eq_or_diff( $raw->readraw( 'foo/fnovok' ), Chisel::RawFile->new( name => 'foo/fnovok', data => undef ) );
throws_ok { $raw->readraw( 'foo/fxxvok' ) } qr/error: NOFETCH/;

# with validation failing, and no context, data should be undef
eq_or_diff( $raw->readraw( 'foo/fokvno' ), Chisel::RawFile->new( name => 'foo/fokvno', data => undef, data_pending => 'xxx' ) );
eq_or_diff( $raw->readraw( 'foo/fnovno' ), Chisel::RawFile->new( name => 'foo/fnovno', data => undef ) );
throws_ok { $raw->readraw( 'foo/fxxvno' ) } qr/error: NOFETCH/;

# same if validation dies
eq_or_diff( $raw->readraw( 'foo/fokvxx' ), Chisel::RawFile->new( name => 'foo/fokvxx', data => undef, data_pending => 'xxx' ) );
eq_or_diff( $raw->readraw( 'foo/fnovxx' ), Chisel::RawFile->new( name => 'foo/fnovxx', data => undef ) );
throws_ok { $raw->readraw( 'foo/fxxvxx' ) } qr/error: NOFETCH/;

# same tests, with context:
my $context = Chisel::RawFile->new( name => 'foo/xxx', data => 'contextual' );

# with validation OK, data should equal whatever fetch returns
eq_or_diff( $raw->readraw( 'foo/fokvok', context => $context ), Chisel::RawFile->new( name => 'foo/fokvok', data => 'xxx' ) );
eq_or_diff( $raw->readraw( 'foo/fnovok', context => $context ), Chisel::RawFile->new( name => 'foo/fnovok', data => undef ) );
throws_ok { $raw->readraw( 'foo/fxxvok' ) } qr/error: NOFETCH/;

# with validation failing, context should be preserved
eq_or_diff( $raw->readraw( 'foo/fokvno', context => $context ), Chisel::RawFile->new( name => 'foo/fokvno', data => 'contextual', data_pending => 'xxx' ) );
eq_or_diff( $raw->readraw( 'foo/fnovno', context => $context ), Chisel::RawFile->new( name => 'foo/fnovno', data => 'contextual' ) );
throws_ok { $raw->readraw( 'foo/fxxvno' ) } qr/error: NOFETCH/;

# same if validation dies
eq_or_diff( $raw->readraw( 'foo/fokvxx', context => $context ), Chisel::RawFile->new( name => 'foo/fokvxx', data => 'contextual', data_pending => 'xxx' ) );
eq_or_diff( $raw->readraw( 'foo/fnovxx', context => $context ), Chisel::RawFile->new( name => 'foo/fnovxx', data => 'contextual' ) );
throws_ok { $raw->readraw( 'foo/fxxvxx' ) } qr/error: NOFETCH/;

# a plugin that has interesting fetch/validate combinations
# fok: fetch OK ; fno: fetch NO, fxx: fetch DIES
# vok/vno/vxx: same for validation
package FakeRawPlugin;
use base 'Chisel::Builder::Raw::Base';
sub fetch {
    my ($self, $arg) = @_;
    if( $arg =~ /fok/ ) {
        return 'xxx';
    } elsif( $arg =~ /fno/ ) {
        return undef;
    } else {
        die "NOFETCH";
    }
}
sub validate {
    my ( $self, $arg, $new, $old ) = @_;
    if( $arg =~ /vok/ ) {
        return 1;
    } elsif( $arg =~ /vno/ ) {
        return undef;
    } else {
        die "NOVAL";
    }
}
