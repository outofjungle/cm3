#!/usr/local/bin/perl

# bucket-loadable.t -- tests the 'loadable' option to a Bucket's constructor

use warnings;
use strict;
use Digest::MD5 qw/md5_hex/;
use File::Temp qw/tempdir/;
use Test::More tests => 6;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Bucket"); }

# try some normal tests
do {
    # we're going to load this into a $bucket
    my @files = (
        { file => "x", blob => "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
        { file => "y", blob => "cccccccccccccccccccccccccccccccccccccccc" },
    );
    
    my $bucket = Chisel::Bucket->new( loadable => sub { \@files } );
    
    # make sure ->add doesn't work
    throws_ok { $bucket->add( file => "a", blob => "dddddddddddddddddddddddddddddddddddddddd" ); } qr/don't call add/;
    
    # this should get included as well
    push @files, { file => "z", blob => "dddddddddddddddddddddddddddddddddddddddd" };
    
    eq_or_diff(
        $bucket->manifest_json( emit => [ 'blob' ] ),
        join( "\n", 
            '{"blob":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","mode":"0644","name":["x"],"type":"file"}',
            '{"blob":"cccccccccccccccccccccccccccccccccccccccc","mode":"0644","name":["y"],"type":"file"}',
            '{"blob":"dddddddddddddddddddddddddddddddddddddddd","mode":"0644","name":["z"],"type":"file"}',
            '' # to get the trailing newline to show up
        ),
        "loadable bucket has the correct files"
    );
    
    # now clear out @files, which should not matter
    @files = ();
    
    eq_or_diff(
        $bucket->manifest_json( emit => [ 'blob' ] ),
        join( "\n", 
            '{"blob":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","mode":"0644","name":["x"],"type":"file"}',
            '{"blob":"cccccccccccccccccccccccccccccccccccccccc","mode":"0644","name":["y"],"type":"file"}',
            '{"blob":"dddddddddddddddddddddddddddddddddddddddd","mode":"0644","name":["z"],"type":"file"}',
            '' # to get the trailing newline to show up
        ),
        "loadable bucket has the correct files, even after adjusting the thing it's loaded from"
    );
};

# try a loader failure
do {
    my @files = ( { file => "x", blob => "notablob" } );
    
    my $bucket = Chisel::Bucket->new( loadable => sub { \@files } );
    
    # try it twice, just to make sure
    throws_ok { $bucket->manifest } qr/unrecognized blob: notablob/;
    throws_ok { $bucket->manifest } qr/unrecognized blob: notablob/;
};
