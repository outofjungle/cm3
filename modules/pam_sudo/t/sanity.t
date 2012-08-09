#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
# keep this number hardcoded, it's a good check against those globs
use Test::More tests => 4;
use Test::ChiselSanityCheck qw/:all/;

sanity_ok( $_ ) for glob "t/files/ok/*";
sanity_dies_with_message( "t/files/insane/freebsd6-too-short", q!pam_sudo file for freebsd6 is too short! );
sanity_dies_with_message( "t/files/insane/rhel4-too-short",    q!pam_sudo file for rhel4 is too short! );
sanity_dies_with_message( "t/files/insane/too-many-files",     q!extra files: freebsd8! );
