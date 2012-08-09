######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::BuilderWeb::ModPerl::Pull;
use warnings;
use strict;

use Apache2::Const qw/:common :http/;
use Apache2::Log;
use Apache2::RequestRec;
use Apache2::Request;
use JSON::XS;
use URI::Escape;
use Chisel::BuilderWeb::ClientValidate qw/validate_request/;
use Chisel::BuilderWeb::Singletons;
use Regexp::Chisel qw/$RE_CHISEL_hostname/;

# feed zk data to client
sub handler {
    my $r    = shift;
    my $req  = Apache2::Request->new( $r );
    my $rlog = $r->log;

    my $last = $req->param( "last" );
    if( !$last || $last !~ /^\d+$/ ) {
        $last = 0;
    }

    # Pull reports from ZooKeeper
    my $reports = Chisel::BuilderWeb::Singletons->with_zk(
        sub {
            my $zk = shift;
            return $zk->reports;
        }
    );

    # Remove any reports prior to $last
    while( my ( $hostname, $report ) = each %$reports ) {
        if( $report->{meta}{received} && $report->{meta}{received} < $last ) {
            delete $reports->{$hostname};
        }
    }

    $r->content_type('application/json');
    print encode_json $reports;
    return OK;
}

1;
    
