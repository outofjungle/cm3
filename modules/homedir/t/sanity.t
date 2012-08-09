#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
use Test::More tests => 6;
use Test::ChiselSanityCheck qw/:all/;

sanity_ok( "t/files.basic" );
sanity_ok( "t/files.with-symlink" );
sanity_dies( "t/files.broken" );
sanity_dies( "t/files.broken-symlink" );
sanity_dies( "t/files.bad-structure" );
sanity_dies( "t/files.bad-username" );
