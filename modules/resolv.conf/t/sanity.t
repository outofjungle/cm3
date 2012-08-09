#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
use Test::More tests => 8;
use Test::ChiselSanityCheck qw/:all/;

sanity_dies( "t/files/bad-domain" );
sanity_dies( "t/files/bad-resolvers" );
sanity_dies( "t/files/bad-search" );
sanity_dies( "t/files/no-resolvers" );
sanity_dies( "t/files/localhost-only" );
sanity_ok( "t/files/norotate" );
sanity_ok( "t/files/rotate" );
sanity_ok( "t/files/with-search-and-domain" );
