#!/usr/local/bin/perl -w

# tests the "sign" function in Chisel::Integrity

use warnings;
use strict;
use File::Temp qw/tempdir/;
use Chisel::Integrity;
use Test::More;
use Test::chiselVerify qw/:all/;

my $tmp        = tempdir( CLEANUP => 1 );
my $tmpfile    = "$tmp/file";               # sign_ok and sign_dies will write content here
my $tmpfileasc = "$tmp/file.asc";           # sign_ok and sign_dies will write detached signature here

my $gnupghome = gnupghome();
my $m = Chisel::Integrity->new( gnupghome => $gnupghome );

# this test case requires the full GPG, so skip if we can't find it
if( system("which gpg") ) {
    plan skip_all => 'gpg binary not present';
    exit 0;
} else {
    plan tests => 8;
}

# create a gnupg homedir
system( "gpg --homedir $gnupghome --import t/files/keyrings/humanring.asc t/files/keyrings/humanring-sec.asc >/dev/null 2>&1" );

# signed by alice, not bob
sign_ok( { contents => "asdf\n", key => "alice" } );
is_signed( { file => $tmpfile, key => "alice" } );
isnt_signed( { file => $tmpfile, key => "bob" } );

# signed by bob only
sign_ok( { contents => "asdf\n", key => "bob" } );
isnt_signed( { file => $tmpfile, key => "alice" } );
is_signed( { file => $tmpfile, key => "bob" } );

# dies on undef content
sign_dies( { contents => undef, key => "bob" } );

# dies with a bad key name
sign_dies( { contents => "asdf\n", key => "bobb" } );

sub sign_ok { # make sure that sign_file works with particular options (e.g. key, ring)
    my ( $args, $message ) = @_;

    $message ||= "content was signed with key = $args->{key}:\n$args->{contents}";
    
    # 1. sign content
    # 2. write content + signature into tmp files
    # 3. verify signature
    
    my $sig = $m->sign(
        contents => $args->{contents},
        key      => $args->{key},
    );
        
    open my $tmpfilefd, ">", $tmpfile
      or die "open $tmpfile: $!\n";
    print $tmpfilefd $args->{contents};
    close $tmpfilefd;
    
    open my $tmpfileascfd, ">", $tmpfileasc
      or die "open $tmpfileasc: $!\n";
    print $tmpfileascfd $sig;
    close $tmpfileascfd;
    
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    ok( $m->verify_file( file => $tmpfile, key => $args->{key} ), $message );
}

sub sign_dies { # make sure that sign_file does NOT work with particular options (e.g. key, ring)
    my ( $args, $message ) = @_;

    $args->{append} ||= 0;
    $message ||= "content was NOT signed with key = $args->{key}:\n$args->{contents}";

    # 1. try sign file
    # 2. ensure it dies
    
    my $r = eval {
        my $sig = $m->sign(
            contents => $args->{contents},
            key      => $args->{key},
        );
        
        1;
    };
    
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is( $r, undef, $message );
}
