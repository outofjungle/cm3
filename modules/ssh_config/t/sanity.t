#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
use Test::More tests => 4;
use Test::ChiselSanityCheck qw/:all/;

sanity_dies( "t/files/invalid" );
sanity_dies( "t/files/wrongfiles" );
sanity_dies( "t/files/zerolength" );
sanity_ok( "t/files/normal" );
