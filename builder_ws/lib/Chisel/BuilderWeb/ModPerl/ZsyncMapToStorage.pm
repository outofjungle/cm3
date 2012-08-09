######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::BuilderWeb::ModPerl::ZsyncMapToStorage;

use strict;

use Apache2::Log;
use Apache2::Const qw/:common :proxy/;
use Apache2::RequestRec;
use Fcntl;
use MDBM_File ();
use Chisel::Builder::Engine;
use Chisel::BuilderWeb::Singletons;
use Regexp::Chisel qw/:all/;

sub handler {
    my ( $r ) = @_;

    # load $ws
    my $ws = Chisel::BuilderWeb::Singletons->ws;

    # kick back to apache unless we're in /zsync (but not /zsync/out/x/azsync.manifest.json or /zsync/out/x/azsync.data)
    if( $r->uri !~ m{^/zsync(?:/|$)} or $r->uri =~ m{^/zsync/out/[^/]+/(?:azsync.manifest.json$|azsync.data/)} ) {
        $r->log->debug("[ZMTS] " . $r->uri . " declined");
        return DECLINED;
    }

    # we're trying to translate uri=/zsync/out/HOSTNAME/FILE -> blob path on disk

    my ( $hostname, $filename );

    if( $r->uri =~ m{^/zsync/out/($RE_CHISEL_hostname)((?:/$RE_CHISEL_filepart)+)\z} ) {
        $hostname = $1;
        $filename = substr $2, 1;    # strip the slash
    } else {
        $r->log->debug( "[ZMTS] " . $r->uri . " -> no hostname, filename" );
        return NOT_FOUND;
    }

    my $blob = $ws->host_file( $hostname, $filename );

    if(!$blob) {
        $r->log->debug( "[ZMTS] " . $r->uri . " -> hostname=$hostname filename=$filename blob=null" );
        return NOT_FOUND;
    } else {
        $r->log->debug( "[ZMTS] " . $r->uri . " -> hostname=$hostname filename=$filename blob=$blob" );
    }

    my $blob_path = $ws->blobloc( $blob );

    # we know the file should be here.
    $r->filename( $blob_path );

    # we don't want any other translation to run
    return OK;
}

1;
