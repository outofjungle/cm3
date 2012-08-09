package Test::chiselVerify;

use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw/tempdir/;
use File::Basename qw/dirname/;
use IPC::Open3 qw/open3/;
use Cwd qw/getcwd/;

use Exporter qw/import/;
our @EXPORT_OK = qw/ wipe_scratch fixtures gnupghome read_version write_version verify_ok verify_dies verify_dies_like is_signed isnt_signed /;
our %EXPORT_TAGS = ( "all" => [@EXPORT_OK], );

# the basic idea of a Test::chiselVerify run is like this:
# - gnupghome will be somewhere in /tmp, it will always be started off with whatever is in t/files/gnupghome.verify
# - instead of /etc/chisel/version there will be a file /tmp/whatever/version, that starts out not existing

our $VERIFY_SCRATCH;

sub scratch { # sets up a scratch directory and returns it
    if( ! $VERIFY_SCRATCH ) {
        my $tmp = tempdir( CLEANUP => 1 );

        # create gnupghome, which will hold keyrings
        mkdir "$tmp/gnupghome"
          or die "mkdir $tmp/gnupghome: $!\n";
        chmod 0700, "$tmp/gnupghome";

        system( "cp", "t/files/gnupghome.verify/humanring.gpg", "$tmp/gnupghome/humanring.gpg" );
        die "cp failed\n" if $?;

        system( "cp", "t/files/gnupghome.verify/autoring.gpg", "$tmp/gnupghome/autoring.gpg" );
        die "cp failed\n" if $?;

        # create fixtures
        system( "cp", "-r", "t/files", "$tmp/fixtures" );
        die "cp failed\n" if $?;
        system( "find $tmp/fixtures -name .svn -print0 | xargs -0 rm -fr" );
        die "can't scrub .svn from fixtures\n" if $?;

        $VERIFY_SCRATCH = $tmp;
    }

    return $VERIFY_SCRATCH;
}

sub wipe_scratch { # "wipes" the scratch directory (really, just forgets about it so a new one gets made)
    undef $VERIFY_SCRATCH;
}

sub fixtures { # location of the fixtures directory
    return scratch() . "/fixtures";
}

sub gnupghome { # location of the gnupghome directory
    return scratch() . "/gnupghome";
}

sub read_version { # current contents of "/etc/chisel/version"-esque file, or undef if nonexistent
    my $path = scratch() . "/version";
    open my $fh, "<", $path
      or die "open $path: $!\n";
    my $contents = do { local $/; <$fh> };
    close $fh
      or die "close $path: $!\n";

    return $contents;
}

sub write_version { # write to "/etc/chisel/version"-esque file, or delete it if passed undef
    my $newversion = shift;

    my $path = scratch() . "/version";

    if( defined $newversion ) {
        open my $fh, ">", $path
          or die "open $path: $!\n";
        print $fh $newversion;
        close $fh
          or die "close $path: $!\n";
    } elsif( -e $path ) {
        unlink $path
          or die "unlink $path: $!\n";
    }
}

sub run_verify { # run chisel_verify with some arguments
    my ( @args ) = @_;

    local $?;

    # always pass --verbose, --gnupghome, and --use-version
    unshift @args, "--verbose";
    unshift @args, "--gnupghome", gnupghome();
    unshift @args, "--use-version", scratch() . "/version";

    # default hostname is "verify-test.example.com"
    if( ! grep { /--use-hostname/ } @args ) {
        unshift @args, "--use-hostname", "verify-test.example.com";
    }

    if( $ENV{chiselTEST_USESYSTEM} ) {
        local $ENV{PATH} = "/var/chisel/bin:/usr/local/bin:/sbin:/usr/sbin:/bin:/usr/bin";
        local $ENV{PERL5LIB} = "/var/chisel/lib/perl5/site_perl";
        unshift @args, "/var/chisel/bin/chisel_verify";
    } else {
        $ENV{PERL5LIB} = "./lib";
        unshift @args, "./bin/chisel_verify";
    }

    my $pid = open3( my $to_verify, my $from_verify, undef, @args ) or die;
    my $output = do { local $/; <$from_verify> };

    close $to_verify;
    close $from_verify;
    waitpid $pid, 0; # sets $?

    return wantarray ? ( $?, $output ) : $?;
}

sub verify_ok { # make sure that chisel_verify accepts something
    my ( $args, $message ) = @_;

    $message ||= "chisel_verify exits cleanly with arguments $args";

    my ( $r, $output ) = run_verify( split /\s+/, $args );
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is( $r, 0, $message ) || diag( $output );
}

sub verify_dies { # make sure that chisel_verify rejects something
    my ( $args, $message ) = @_;

    $message ||= "chisel_verify dies with arguments $args";

    my ( $r, $output ) = run_verify( split /\s+/, $args );
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    isnt( $r, 0, $message ) || diag( $output );
}

sub verify_dies_like { # make sure that chisel_verify rejects something and also emits a particular error message
    my ( $args, $like_re, $message ) = @_;

    $message ||= "chisel_verify dies with arguments $args";

    my ( $r, $output ) = run_verify( split /\s+/, $args );
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    if( $r == 0 ) {
        fail( $message );
    } else {
        like( $output, $like_re, $message )
    }
}

sub is_signed { # make sure that some file is signed with particular options (e.g. key, ring)
    my ( $args, $message ) = @_;

    my $m = Chisel::Integrity->new( gnupghome => gnupghome() );
    $message ||= "$args->{file} is signed with key = $args->{key}" . (defined $args->{ring} ? " from ring = $args->{ring}" : "");

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    ok( $m->verify_file( file => $args->{file}, key => $args->{key}, ring => $args->{ring} ), $message );
}

sub isnt_signed { # make sure that some file is NOT signed with particular options (e.g. key, ring)
    my ( $args, $message ) = @_;

    my $m = Chisel::Integrity->new( gnupghome => gnupghome() );
    $message ||= "$args->{file} is NOT signed with key = $args->{key}" . (defined $args->{ring} ? " from ring = $args->{ring}" : "");

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    ok( !$m->verify_file( file => $args->{file}, key => $args->{key}, ring => $args->{ring} ), $message );
}

1;
