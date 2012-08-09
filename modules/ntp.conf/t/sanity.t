#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
use Test::More tests => 2;
use Test::ChiselSanityCheck qw/:all/;

sanity_dies( "t/files/bad-restrict" );
sanity_ok( "t/files/ysysbuilder-default" );