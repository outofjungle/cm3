#!/usr/local/bin/perl -w

# rmdir.t -- tests whether azsync can remove an entire directory and then add it back

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 13;
use Test::azsync qw/:all/;

$Test::azsync::AZSYNC_URL = $ENV{AZSYNC_TEST_URL}
  or die "you need to set AZSYNC_TEST_URL\n";
    
# checking existence of the directory '/files/motd'

# should start existing
azsync_ok( "bucket" );
ok( -d "$AZSYNC_SCRATCH/current/files/motd", "files/motd exists at the start" );
ok( -f "$AZSYNC_SCRATCH/current/files/motd/MAIN", "files/motd/MAIN exists at the start" );

# should go away
azsync_ok( "bucket.nomotd" );
ok( ! -e "$AZSYNC_SCRATCH/current/files/motd", "files/motd is gone" );
ok( ! -e "$AZSYNC_SCRATCH/current/files/motd/MAIN", "files/motd/MAIN is gone" );

# then come back
azsync_ok( "bucket" );
ok( -d "$AZSYNC_SCRATCH/current/files/motd", "files/motd came back" );
ok( -f "$AZSYNC_SCRATCH/current/files/motd/MAIN", "files/motd/MAIN came back" );

# now remove a multilevel tree
azsync_ok( "bucket.nofiles" );
ok( ! -e "$AZSYNC_SCRATCH/current/files", "'files' is gone" );

# bring it back
azsync_ok( "bucket" );
ok( -d "$AZSYNC_SCRATCH/current/files", "'files' came back" );
