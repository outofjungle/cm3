######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::BuilderWeb::ModPerl::Report;
use warnings;
use strict;

use Apache2::Const qw/:common :http/;
use Apache2::Log;
use Apache2::RequestRec;
use JSON::XS;
use URI::Escape;
use Chisel::BuilderWeb::ClientValidate qw/validate_request/;
use Chisel::BuilderWeb::Singletons;
use Regexp::Chisel qw/$RE_CHISEL_hostname/;

sub handler {
    my $r    = shift;
    my $rlog = $r->log;

    my $reports = {};
    my $hostname;

    my $content_type = $r->headers_in->{'Content-Type'};
    if ($content_type ne 'application/json' ) {
        $rlog->error( "Old/bad client failed to report" );
        return HTTP_BAD_REQUEST;
    }

    my $content_length = $r->headers_in->{'Content-Length'}
      or return HTTP_BAD_REQUEST;

    # Don't allow reports > 4k
    if($content_length > 4096) {
        $rlog->error( "Report too large" );
        return HTTP_BAD_REQUEST;
    }

    my $reports_raw = '';
    while( $content_length ) {
        my $bytes = $r->read( $reports_raw, $content_length, length $reports_raw );
        $content_length -= $bytes;
    }

    # get hostname, verify JSON is OK
    eval {
        $reports = decode_json $reports_raw;
    } or do {
        $rlog->error( "Bad report: $@" );
        return SERVER_ERROR;
    };
    if( ! keys %$reports ) {
        $rlog->error( "Empty report" );
        return HTTP_BAD_REQUEST;
    }

    $hostname = $reports->{meta}{hostname};

    # untaint and validate the hostname we found
    if( defined( $hostname ) and $hostname =~ m/^($RE_CHISEL_hostname)$/ ) {
        $hostname = $1;
    } else {
        $rlog->error( "Bad hostname: $hostname" );
        return SERVER_ERROR;
    }

    return HTTP_FORBIDDEN unless( validate_request( $r, $hostname ) );

    # validate contents of $reports. On failure an error is logged and only meta is recorded.
    eval {
        foreach my $script ( grep { $_ ne 'meta' } keys %$reports )
        {
            my ( $code, $runtime, $version ) = @{ $reports->{$script} };
            die "script='$script'"   unless( defined( $script )  and $script  =~ m/[a-zA-Z][\w\.\-\{\}]*/ );
            die "code='$code'"       unless( defined( $code )    and $code    =~ m/^\d+$/ );
            die "runtime='$runtime'" unless( defined( $runtime ) and $runtime =~ m/^\d+$/ );
            die "version='$version'" unless( defined( $version ) and $version =~ m/^\d*$/ );
        }
        1;
    } or do {
        $rlog->error( "Bad Report: $@" );
        delete $reports->{ grep { $_ ne 'meta' } keys %$reports };
    };

    # add timestamps to script reports
    my $now = scalar time;
    $reports->{meta}{received} = $now;
    foreach my $script ( grep { $_ ne 'meta' } keys %$reports ) {
        unshift @{ $reports->{$script} }, $now;
    }

    # write to zk
    Chisel::BuilderWeb::Singletons->with_zk(
        sub {
            my $zk = shift;
            $zk->report( $hostname, $reports );
        }
    );

    return HTTP_NO_CONTENT;
}

1;
