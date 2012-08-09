######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::BuilderWeb::ClientValidate;

use strict;

use Apache2::Log;
use Apache2::RequestRec;
use Apache2::Connection;
use APR::SockAddr;
use Socket;

use Exporter qw/import/;
our @EXPORT_OK = qw/validate_request/;

sub validate_request {
    my ( $r, $hostname ) = @_;

    my $check = $ENV{'validate_request'};
    if( $check ne 'warn' && $check ne 'off' && $check ne 'deny' ) {
        $r->log->warn( "builder_ws.validate_request not 'warn' or 'off', defaulting to 'deny'" );
        $check = 'deny';
    }

    if( $hostname && $hostname =~ m{^([\w\d][\w\d\-]*(?:\.[\w\d\-]+)+)$} ) {

        # skip checks if they're disabled
        if( $check eq 'off' ) {
            $r->log->debug( "[VALIDATE OK] checks are disabled" );
            return 'ok';
        }

        my $remote_addr = get_remote_addr( $r );

        # (optionally) look at client cert cn, if present
        if( $ENV{'allow_client_certs'} && $ENV{'allow_client_certs'} =~ /^(yes|on|true|1)$/ ) {
            my $remote_cn = get_client_cert_cn( $r );

            if( $remote_cn && $remote_cn eq $hostname ) {
                $r->log->debug( "[VALIDATE OK] $hostname (src ip $remote_addr) valid based on client certificate" );
                return 'ok';
            }
        }

        # next fall back to the source ip address

        my ( undef, undef, $addrtype, undef, @addrs ) = gethostbyname("$hostname.");

        if( $addrtype == AF_INET and @addrs ) {
            foreach my $addr (@addrs) {
                if( inet_ntoa($addr) eq $remote_addr) {
                    $r->log->debug( "[VALIDATE OK] $hostname (src ip $remote_addr) valid based on source address" );
                    return 'ok';
                }
            }

            # $hostname is in DNS, but there was no match
            $r->log->error( "[VALIDATE IP_MISMATCH] $remote_addr requested for '$hostname'" );
        } else {
            # $hostname not in DNS
            $r->log->error( "[VALIDATE IP_MISMATCH] $remote_addr requested for '$hostname', which is not in DNS" );
        }

        # if we are here, client is invalid
        return $check eq 'deny' ? undef : 'ok';
    } else {

        # bad hostname
        my $remote_addr = get_remote_addr( $r );

        $r->log->error( "[VALIDATE NOT_HOSTNAME] $remote_addr requested for '$hostname', which is not a valid hostname" );
        return undef;
    }
}

sub get_client_cert_cn {
    my ( $r ) = @_;

    my $cn;

    # $r->connection->remote_addr will be the ystunnel remote addr, not the actual
    # client -- this is what we want, since it's what the libystunnel api expects
    # XXX - This code might not work with yapache 2 :(
    
}

sub get_remote_addr {
    my ( $r ) = @_;

    # $r->connection->remote_addr is broken when used with stunnel. Should use yapache_get_remote_ip()
    # but will have to settle for $r->subprocess_env->get('mod_remote_ip::remote_ip'). Still have
    # the connection->remote_addr code path as a fallback.
    my $remote_addr;

    

    return $remote_addr;
}

1;
