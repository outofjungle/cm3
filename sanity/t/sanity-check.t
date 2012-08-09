#!/usr/local/bin/perl

# sanity-check.t -- check a few sample buckets

use warnings;
use strict;
use Test::More tests => 22;
use Test::Exception;
use Test::chiselSanity qw/:all/;
use Digest::MD5 qw/md5_hex/;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

# there will be one persistent sanity checker
# since it's supposed to be able to handle a series of requests
my $sanity = new_sanity();

# first try a bucket that should be totally ok
check_ok( { 'files/numbers/MAIN' => "1234\n5678\n", 
            'files/letters/MAIN' => "abcd\nefgh\n", } );

# try different, but still good, files
check_ok( { 'files/numbers/MAIN' => "987\n",
            'files/letters/MAIN' => "xyz\n", } );

# now break it a little
check_throws( { 'files/numbers/MAIN' => "1234\n5678\n",
                'files/letters/MAIN' => "1234\n5678\n", }, 
                qr/FAILED letters files/ );

# restore normality by deleting the 'letters' file
check_ok( { 'files/numbers/MAIN' => "1234\n5678\n", } );

# try a zero-length file (not supposed to be allowed)
check_throws( { 'files/numbers/MAIN' => "", }, qr/FAILED numbers files/ );

# ok now change the name of that 'numbers' file
check_throws( { 'files/numbers/MAINN' => "1234\n5678\n", },
                qr/FAILED numbers files/ );

# try the original plus some scripts
check_ok( { 'files/numbers/MAIN' => "1234\n5678\n",
            'files/letters/MAIN' => "abcd\nefgh\n",
            'scripts/numbers'    => "im a script hi\n", } );

# try fake script 'numberz'
check_throws( { 'files/numbers/MAIN' => "1234\n5678\n",
                'files/letters/MAIN' => "abcd\nefgh\n",
                'scripts/numbers'    => "im a script hi\n",
                'scripts/numberz'    => "im also a script\n", }, 
                qr/missing sanity-check for module numberz/ );

# try fake file 'numberz'
check_throws( { 'files/numberz/MAIN' => "1234\n5678\n", },
                qr/missing sanity-check for module numberz/ );

# try bad top-level files
check_throws( { 'files/numbers/MAIN' => "1234\n5678\n",
                'ROFL' => "1234\n5678\n" },
                qr/ROFL does not look like a legitimate file name/ );

# try various bad paths
my @bad_paths = qw{ xxx/numbers/MAIN files/numbers/rofl/MAIN files/numbers scripts/numbers/xxx files/numbers/.MAIN };
foreach my $bad_path (@bad_paths) {
    check_throws( { $bad_path => "1234\n" }, qr/\Q$bad_path\E does not look like a legitimate file name/ );
}

# make sure the original still works
check_ok( { 'files/numbers/MAIN' => "1234\n5678\n",
            'files/letters/MAIN' => "abcd\nefgh\n", } );

# try various things with a multi-file module ('twofiles')
check_ok( { 'files/numbers/MAIN'     => "1234\n5678\n",
            'files/letters/MAIN'     => "abcd\nefgh\n",
            'files/twofiles/numbers' => "1234\n5678\n",
            'files/twofiles/letters' => "abcd\nefgh\n", } );

# rename 'numbers' and 'letters' to 'number' and 'letter'
check_throws( { 'files/numbers/MAIN'     => "1234\n5678\n",
                'files/letters/MAIN'     => "abcd\nefgh\n",
                'files/twofiles/number'  => "1234\n5678\n",
                'files/twofiles/letter'  => "abcd\nefgh\n", }, 
                qr/FAILED twofiles files/ );

# add a number to the 'letters' file -- should fail
check_throws( { 'files/numbers/MAIN'     => "1234\n5678\n",
                'files/letters/MAIN'     => "abcd\nefgh\n",
                'files/twofiles/numbers' => "1234\n5678\n",
                'files/twofiles/letters' => "abcd\nefgh0\n", }, 
                qr/FAILED twofiles files/ );

# swap contents of the good 'numbers' and 'letters' files -- should fail
check_throws( { 'files/numbers/MAIN'     => "1234\n5678\n",
                'files/letters/MAIN'     => "abcd\nefgh\n",
                'files/twofiles/letters' => "1234\n5678\n",
                'files/twofiles/numbers' => "abcd\nefgh\n", }, 
                qr/FAILED twofiles files/ );

# remove 'letters' file
check_throws( { 'files/numbers/MAIN'     => "1234\n5678\n",
                'files/letters/MAIN'     => "abcd\nefgh\n",
                'files/twofiles/numbers' => "1234\n5678\n", }, 
                qr/FAILED twofiles files/ );

# different good files, but should still be good
check_ok( { 'files/numbers/MAIN'     => "1234\n5678\n",
            'files/letters/MAIN'     => "abcd\nefgh\n",
            'files/twofiles/numbers' => "9870\n",
            'files/twofiles/letters' => "abcd\nefgh\n", } );

# ensures a set of files are ok
sub check_ok {
    my ( $files, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    
    $message ||= "sanity checker accepts " . join( " ", map { "$_ -> '$files->{$_}'" } keys %$files );
    
    my $manifest = make_manifest($files);
    
    # sanity checker will need these blobs
    $sanity->add_blob( contents => $_ ) for values %$files;
    $sanity->add_blob( contents => $manifest );
    
    # try it twice
    my $sig1 = $sanity->check_bucket( manifest => $manifest );
    my $sig2 = $sanity->check_bucket( manifest => $manifest );
    
    subtest $message => sub {
        plan tests => 2;
        like( $sig1, qr/^(-----BEGIN PGP SIGNATURE-----\n[\w\d:\-\+\=\/\(\)\.\s]+-----END PGP SIGNATURE-----\n)$/, "sanity checker returned a gpg signature" );
        like( $sig2, qr/^(-----BEGIN PGP SIGNATURE-----\n[\w\d:\-\+\=\/\(\)\.\s]+-----END PGP SIGNATURE-----\n)$/, "sanity checker returned a gpg signature" );        
    };
}

# ensures a set of files are NOT ok
# requires an error string to look for
sub check_throws {
    my ( $files, $error, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    
    $message ||= "sanity checker rejects " . join( " ", map { "$_ -> '$files->{$_}'" } keys %$files );
    
    my $manifest = make_manifest($files);
    
    # sanity checker will need these blobs
    $sanity->add_blob( contents => $_ ) for values %$files;
    $sanity->add_blob( contents => $manifest );
    
    # try it twice
    subtest $message => sub {
        plan tests => 2;
        throws_ok { $sanity->check_bucket( manifest => $manifest ); } $error, $message;
        throws_ok { $sanity->check_bucket( manifest => $manifest ); } $error, $message;
    };
}

# input: %files hash like the ones up above
# output: standard format MANIFEST file
sub make_manifest {
    my ( $files ) = @_;
    
    my $manifest = "";
    
    foreach my $f (sort keys %$files) {
        my $mode = ( $f =~ /^scripts\// ) ? '0755' : '0644';
        my $md5 = md5_hex($files->{$f});
        $manifest .= qq!{"mode":"$mode","name":["$f"],"type":"file","md5":"$md5"}\n!;
    }
    
    return $manifest;
}
