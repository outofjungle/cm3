######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::BuilderWeb::ModPerl::ClusterProxy;

use strict;

use Apache2::Log;
use Apache2::Const qw/:common :proxy/;
use Apache2::RequestRec;
use Regexp::Chisel qw/:all/;
use Log::Log4perl qw/:easy/;
use Chisel::Builder::Engine;
use Sys::Hostname ();
use Chisel::BuilderWeb::Singletons;

sub handler {
    my ( $r ) = @_;

    # We're trying to decide if some uri /foo/HOSTNAME should be served locally
    # or proxied to another server in the cluster (the primary for "hostname")

    my @matches = split /;/, $r->dir_config('clusterproxy_match');

    my $matched;
    my $hostname;
    my $style; # "proxy" or "redirect"

    for my $cfg ( @matches ) {
        my $match;
        ($match, $style) = $cfg =~ /^(.*?)(?:\:(proxy|redirect))?$/;

        if(!$match) {
            # Bad configuration
            $r->log->error("[CLUSTER PROXY] Bogus configuration item $cfg");
            return SERVER_ERROR;
        }

        warn "[$match] [$style]";
        my $matchre = '^' . quotemeta( $match . "/" );
        if( $r->uri =~ /$matchre/ ) {
            $matched = $match;
            ($hostname) = $r->uri =~ m!${matchre}(${RE_CHISEL_hostname})(?:/|$)!;
            last;
        }
    }

    if( !$matched ) {
        # Not inside a clusterproxy_match location. Kick the request back to apache
        $r->log->debug( sprintf "[CLUSTER PROXY] %s declined", $r->uri );
        return DECLINED;
    } elsif( !$hostname ) {
        # We're inside a clusterproxy_match location but could not find a valid hostname
        $r->log->debug( sprintf "[CLUSTER PROXY] %s inside <%s> with no hostname", $r->uri, $matched );
        return NOT_FOUND;
    } else {
        $r->log->debug( sprintf "[CLUSTER PROXY] %s inside <%s> with hostname <%s>", $r->uri, $matched, $hostname );
    }

    # Check ZooKeeper to see who is responsible for $hostname
    my $primary;
    my $name;

    Chisel::BuilderWeb::Singletons->with_zk(
        sub {
            my $zk = shift;
            $primary = $zk->get_worker_for_host( $hostname );
            $name    = $zk->name;
        }
    );

    if( !$primary ) {
        # No primary found for this hostname
        $r->log->debug( "[CLUSTER PROXY] $hostname -> not found" );
        return NOT_FOUND;
    } elsif( $primary ne $name ) {
        # We need to proxy/redirect this request to $primary
        $r->log->debug( "[CLUSTER PROXY] $hostname -> $style to $primary" );

        if($style eq 'proxy') {
            # What port to use?
            # XXX need a setting
            my $http_port = 4081;
            my $proxyto = "http://${primary}:${http_port}" . $r->uri;

            # Reverse proxy request to $proxyto
            $r->proxyreq(PROXYREQ_REVERSE);
            $r->uri($proxyto);
            $r->filename("proxy:$proxyto");
            $r->handler('proxy-server');

            return OK;
        } elsif($style eq 'redirect') {
            # What port to use?
            # XXX need a setting
            my $http_port = 4443;
            my $redirto = "https://${primary}:${http_port}" . $r->uri;
            $r->headers_out->{"Location"} = $redirto;
            return REDIRECT;
        } else {
            # Err? Shouldn't happen
            $r->log->error("[CLUSTER PROXY] Oops! Internal error!");
            return SERVER_ERROR;
        }
    } else {
        # We can serve this request locally
        $r->log->debug( "[CLUSTER PROXY] $hostname -> local" );
        return DECLINED;
    }
}

1;
