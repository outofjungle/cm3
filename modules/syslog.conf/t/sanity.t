#!/usr/local/bin/perl -w

use warnings;
use strict;
use lib '../../t';
# keep this number hardcoded, it's a good check against those globs
use Test::More tests => 5;
use Test::ChiselSanityCheck qw/:all/;

sanity_ok( $_ )   for glob "t/files/ok/*";
sanity_dies_with_message( "t/files/insane/freebsd-wrong-format", "freebsd: bad selector \$ModLoad" );
sanity_dies_with_message( "t/files/insane/linux-program-specification", "linux: no selector: !ipfw" );
sanity_dies_with_message( "t/files/insane/linux-too-short", "linux: not enough lines" );
sanity_dies_with_message( "t/files/insane/linux-wrong-format", "linux: bad selector \$ModLoad" );
