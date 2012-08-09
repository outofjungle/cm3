#!/usr/local/bin/perl

# sanity-no-blobs.t -- test what happens when not enough blobs are given to check a manifest

use warnings;
use strict;
use Test::More tests => 4;
use Test::Exception;
use Test::chiselSanity qw/:all/;
use Digest::MD5 qw/md5_hex/;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $sanity = new_sanity();

do {
    # 210878d65ca1f42f223de5f1d18ec19b = "abcd\nefgh\n"
    # 9053253e972cf40443a4083f452f24d4 = "1234\n5678\n"
    
    my $manifest = <<EOT;
{"mode":"0644","name":["files/letters/MAIN"],"type":"file","md5":"210878d65ca1f42f223de5f1d18ec19b"}
{"mode":"0644","name":["files/numbers/MAIN"],"type":"file","md5":"9053253e972cf40443a4083f452f24d4"}
EOT

    # try the manifest by itself
    dies_ok { $sanity->check_bucket( manifest => $manifest ) } "sanity checker dies if given 0/2 blobs";

    # give it one
    $sanity->add_blob( contents => "1234\n5678\n" );
    dies_ok { $sanity->check_bucket( manifest => $manifest ) } "sanity checker dies if given 1/2 blobs";

    # give it another
    $sanity->add_blob( contents => "abcd\nefgh\n" );
    like( $sanity->check_bucket( manifest => $manifest ), qr/---BEGIN PGP SIGNATURE---/, "sanity checker works if given 2/2 blobs" );
};

# double up on the files, it should fail now
do {
    my $manifest = <<EOT;
{"mode":"0644","name":["files/letters/MAIN"],"type":"file","md5":"210878d65ca1f42f223de5f1d18ec19b"}
{"mode":"0644","name":["files/numbers/MAIN"],"type":"file","md5":"210878d65ca1f42f223de5f1d18ec19b"}
EOT
    
    throws_ok { $sanity->check_bucket( manifest => $manifest ) }
    qr/FAILED numbers files/,
        "sanity checker fails on a bad manifest with the same blobs";
};
