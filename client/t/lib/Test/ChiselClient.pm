package Test::ChiselClient;

use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Find;
use Digest::MD5 qw/md5_hex/;
use File::Temp qw/tempdir/;
use File::Basename qw/dirname/;
use Data::Dumper;
use Cwd qw/getcwd/;

use Exporter qw/import/;
our @EXPORT_OK = qw/ client_ok client_dies scratch_is $SCRATCH /;
our %EXPORT_TAGS = ( "all" => [@EXPORT_OK], );

our $SCRATCH;

sub new_scratch { # sets up a scratch directory and returns it
    my ( %args ) = @_;

    return $SCRATCH = tempdir( CLEANUP => 1 );
}

sub run_client { # run the client with some parameters
    my ( $args ) = @_;

    new_scratch();

    local $ENV{ChiselTEST_OUTDIR} = $SCRATCH;

    if( $ENV{ChiselTEST_USESYSTEM} ) {
        local $ENV{PATH} = "/var/chisel/bin:/usr/local/bin:/sbin:/usr/sbin:/bin:/usr/bin";
        local $ENV{PERL5LIB} = "/var/chisel/lib/perl5/site_perl";
        return system( "/var/chisel/bin/chisel_client", @$args );
    } else {
        return system( "/usr/local/bin/perl", "-w", "root/var/chisel/bin/chisel_client", @$args );
    }
}

sub client_ok { # run the client with some parameters
    my ( $args, $message ) = @_;
    if( !$message || $message =~ /^\[.+\]$/ ) {
        $message &&= "$message ";
        $message .= qq{"chisel_client @$args" should exit cleanly};
    }

    my $r = run_client( $args );
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is( $r, 0, $message );
}

sub client_dies { # run the client with some parameters, but expect it to die
    my ( $args, $message ) = @_;
    if( !$message || $message =~ /^\[.+\]$/ ) {
        $message &&= "$message ";
        $message .= qq{"chisel_client @$args" should die};
    }

    my $r = run_client( $args );
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    isnt( $r, 0, $message );
}

sub scratch_is {
    my ( $spec, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    if( !$message || $message =~ /^\[.+\]$/ ) {
        local $Data::Dumper::Terse = 1;
        local $Data::Dumper::Sortkeys = 1;
        $message &&= "$message ";
        $message .= qq{scratch matches spec:\n} . Dumper($spec);
    }

    if( !$SCRATCH ) {
        return fail( "Called scratch_is before setting \$SCRATCH" );
    }

    my $oldcwd = getcwd;

    my $m_scratch = _scan( $SCRATCH );
    my $m_spec = join '', sort map { quotemeta("./$_") . " " . md5_hex($spec->{$_}) . " " . "33188\n" } keys %$spec;

    chdir $oldcwd
      or die "can't chdir back to $oldcwd: $!";

    is( $m_scratch, $m_spec, $message );
}

sub _scan {
    my ( $dir, %args ) = @_;

    my $ignore_azsync_md = $args{'ignore_azsync_md'};

    chdir $dir
      or do { return '' };

    my @manifest;

    File::Find::find(
        sub {
            my $absname = $File::Find::name;
            my $relname = $_;

            # skip . and ..
            return if $absname eq '.' || $absname eq '..';

            # record this
            my $mode = ( stat $relname )[2] or die __PACKAGE__ . ": internal error: can't stat $absname ($!)";
            my $contents =
                -l $relname ? "<symlink to:" . ( readlink( $relname ) || die "can't readlink $relname:$!" ) . ">"
              : -d $relname ? "<directory>"
              : -f $relname ? do { open my $fh, "<", $relname; local $/; <$fh>; }
              :               die "$relname: not a link, dir, or file";

            my @stuff = ( quotemeta($absname), md5_hex($contents), $mode );
            push @stuff, readlink $relname if -l $relname;
            push @manifest, join(" ", @stuff) . "\n";
        },
        '.'
    );

    return join '', sort @manifest;
}

1;
