#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
# keep this number hardcoded, it's a good check against those globs
use Test::More tests => 12;
use Test::ChiselSanityCheck qw/:all/;

sanity_dies( $_ ) for glob "t/files/insane/*";
sanity_ok( $_ )   for glob "t/files/ok/*";
