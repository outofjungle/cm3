######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::BuilderWeb::ModPerl::ZsyncAzsyncData;

use strict;

use Apache2::Const qw/:common :proxy/;
use Apache2::Log;
use Apache2::RequestRec;
use Digest::MD5 qw/md5_hex/;
use Fcntl;
use IPC::Run ();
use MDBM_File ();
use Cache::Memcached;
use Chisel::Builder::Engine;
use Chisel::BuilderWeb::Singletons;
use Regexp::Chisel qw/:all/;

sub handler {
    my ( $r ) = @_;

    # load $ws, $memcache
    my $ws       = Chisel::BuilderWeb::Singletons->ws;
    my $memcache = Chisel::BuilderWeb::Singletons->memcache;

    # extract hostname and filename from url
    my ( $hostname, $filename );

    if( $r->uri =~ m{^/zsync/out/($RE_CHISEL_hostname)((?:/$RE_CHISEL_filepart)+)\z} ) {
        $hostname = $1;
        $filename = substr $2, 1; # strip the slash
    } else {
        $r->log->debug( "[ZAD] " . $r->uri . " -> no hostname, filename" );
        return NOT_FOUND;
    }

    $r->log->debug( "[ZAD] " . $r->uri . " -> hostname=$hostname, filename=$filename" );

    # extract bucketid for this host
    my $bucketid = $ws->host_bucketid( $hostname );
    if(!$bucketid) {
        # host has no bucket
        return NOT_FOUND;
    } elsif( my $data = $memcache->get("f$bucketid/$filename") ) {
        # file is cached for this bucket, just return it
        print $data;
        return OK;
    } elsif( $filename eq 'azsync.manifest.json' ) {
        # we need an azsync manifest for $bucketid
        my $bucket = $ws->bucket($bucketid);
        if(!$bucket) {
            return NOT_FOUND;
        }

        # need to create a new Bucket that contains MD5s and mtimes of the various files
        my $manifest = $bucket->manifest( emit => ['blob'] );
        if(!$manifest->{'MANIFEST'}) {
            # no MANIFEST present, this bucket is probably an error bucket
            return NOT_FOUND;
        }

        my $azsync_manifest_json_bucket = Chisel::Bucket->new;
        foreach my $f (keys %$manifest) {
            my $blob  = $manifest->{$f}{'blob'};

            my $md5;
            if( !( $md5 = $memcache->get( "md5$blob" ) ) ) {
                $md5 = md5_hex( $ws->cat_blob( $blob ) );
                $memcache->set( "md5$blob", $md5 );
            }

            my $mtime = ( stat $ws->blobloc( $blob ) )[9];

            $azsync_manifest_json_bucket->add(
                file  => $f,
                blob  => $blob,
                mtime => $mtime,
                md5   => $md5,
            );
        }

        my $data = $azsync_manifest_json_bucket->manifest_json( emit => [ 'name', 'mtime', 'md5', 'type', 'mode' ] );
        $memcache->set("f$bucketid/$filename", $data);

        print $data;
        return OK;
    } elsif( $filename =~ m{^azsync.data/(.+)} ) {
        $filename = $1;

        # we need zsync metadata for $bucketid's $filename
        my $bucket = $ws->bucket($bucketid);
        if(!$bucket) {
            return NOT_FOUND;
        }

        my $manifest = $bucket->manifest( emit => ['blob'] );
        my $blob = $manifest->{$filename} && $manifest->{$filename}{'blob'};
        if( !$blob ) {
            return NOT_FOUND;
        }

        my $contents = $ws->cat_blob( $blob );
        # my $url = "/zsync/out/$hostname/$filename";
        my $url = ( '../' . ( '../' x scalar $filename =~ tr!/!! ) . $filename );

        my $tozs = $contents;
        my $fromzs = '';
        my $errzs = '';

        # -u: URL. Instead of "files/xxx" we want to use $url
        # -Z: overrides the default behaviour and treats gzip files as just binary data
        my $rc = IPC::Run::run( ["/bin64/zsyncmake", "-Z", "-u", $url], \$tozs, \$fromzs, \$errzs );
        if( $rc ) {
            # OK
            # dummy filename due to bug 5304059
            my $data = "Filename: DUMMY\n" . $fromzs;
            $memcache->set("f$bucketid/azsync.data/$filename", $data);
            print $data;
            return OK;
        } else {
            # Error
            $r->log->error( "zsyncmake failed on $blob! (status = $?) (msg = $errzs)" );
            return SERVER_ERROR;
        }
    }

    # should not get this far, but just in case
    return SERVER_ERROR;
}

1;
