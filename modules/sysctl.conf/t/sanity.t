#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
use Test::More tests => 3;
use Test::ChiselSanityCheck qw/:all/;

sanity_dies( "t/files/invalid" );
sanity_dies( "t/files/zerolength" );
sanity_ok( "t/files/normal" );
