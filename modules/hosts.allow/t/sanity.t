#!/usr/bin/perl -w

use warnings;
use strict;
use lib '../../t';
use Test::More tests => 16;
use Test::ChiselSanityCheck qw/:all/;

sanity_dies_with_message( "t/files/insane/all-daemon-allow", q!ERROR: ALL : ALL : allow is unrecognizable! );
sanity_dies_with_message( "t/files/insane/badoption",        q!ERROR: ALL : 64.198.211.64 : badoption is unrecognizable! );
sanity_dies_with_message( "t/files/insane/dupe",             q!ERROR: ALL : 66.18.114.144 : allow is contained within 66.18.114.144/32! );
sanity_dies_with_message( "t/files/insane/dupe-ipv6",        q!ERROR: ALL : [2001:4998::]/32 : allow is contained within 2001:4998:0:0:0:0:0:0/32! );
sanity_dies_with_message( "t/files/insane/goofycidr",        q!ERROR: ALL : 65.164.123.28/. : allow is not a valid CIDR block! );
sanity_dies_with_message( "t/files/insane/innerlater",       q!ERROR: ALL : 69.147.83.0/255.255.255.128 : deny is contained within 69.147.64.0/18! );
sanity_dies_with_message( "t/files/insane/innerlater-ipv6",  q!ERROR: ALL : [2001:49a8:0:0001::]/64 : deny is contained within 2001:49A8:0:0:0:0:0:0/32! );
sanity_dies_with_message( "t/files/insane/nodeny",           q!ERROR: 'ALL : ALL : deny' was not found! );
sanity_dies_with_message( "t/files/insane/nolocal",          q!ERROR: 'ALL : 127.0.0.0/255.0.0.0 : allow' was not found! );
sanity_dies_with_message( "t/files/insane/oodeny",           q!ERROR: 'ALL : ALL : deny' is not the final entry! );
sanity_dies_with_message( "t/files/insane/tooshort",         q!ERROR: Not enough netblocks (only 2 are present)! );
sanity_dies_with_message( "t/files/insane/unicorn",          q!ERROR:                                     <.'_.'' is unrecognizable! );
sanity_dies_with_message( "t/files/insane/xxx-daemon-allow", q!ERROR: XXX : ALL : allow is unrecognizable! );

sanity_ok( "t/files/ok/sendmail-daemon-allow" );
sanity_ok( "t/files/ok/with-ipv6" );
sanity_ok( "t/files/ok/without-ipv6" );
