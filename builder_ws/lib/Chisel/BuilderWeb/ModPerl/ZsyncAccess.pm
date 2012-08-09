######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::BuilderWeb::ModPerl::ZsyncAccess;

use strict;

use Apache2::Log;
use Apache2::Const qw/:common/;
use Apache2::RequestRec;
use Chisel::BuilderWeb::ClientValidate qw/validate_request/;
use Regexp::Chisel qw/:all/;

sub handler {
    my ( $r ) = @_;

    if( $r->uri =~ m{^/zsync/out/($RE_CHISEL_hostname)((?:/$RE_CHISEL_filepart)+)\z} ) {
        my $hostname = $1;
        my $rest = substr $2, 1; # strip the slash

        if( $rest eq 'MANIFEST' or $rest eq 'azsync.manifest.json' ) {
            # always allowed
            return OK;
        } else {
            # check if it's a self-request
            return validate_request( $r, $hostname ) ? OK : FORBIDDEN;
        }
    } else {
        # not a recognized service
        $r->log->debug("[VALIDATE BAD_URL] " . $r->uri);
        return FORBIDDEN;
    }
}

1;
