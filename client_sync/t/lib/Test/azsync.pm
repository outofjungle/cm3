package Test::azsync;

use strict;
use warnings;

use Cwd qw/getcwd/;
use Digest::MD5 qw/md5_hex/;
use File::Find qw/find/;
use File::Temp qw/tempdir/;
use IPC::Open3 qw/open3/;
use Test::More;

use Exporter qw/import/;
our @EXPORT_OK = qw/ scratch scratch_is_gone bucket azsync azsync_ok azsync_dies scratch_is scratch_isnt wipe_scratch $AZSYNC_SCRATCH /;
our %EXPORT_TAGS = ( "all" => [@EXPORT_OK] );

our $AZSYNC_SCRATCH;
our $AZSYNC_URL;
our $AZSYNC_WD;

BEGIN {
    $AZSYNC_WD = getcwd;

    # necessary hack because this doesn't get preserved in svn
    chmod 0666, "$AZSYNC_WD/t/files/azsync/bucket.tweak/REPO";
}

sub scratch {
    if( ! $AZSYNC_SCRATCH ) {
        $AZSYNC_SCRATCH = tempdir( CLEANUP => 1 );
        mkdir "$AZSYNC_SCRATCH/scratch"
          or die "can't mkdir $AZSYNC_SCRATCH/scratch: $!";
    }

    return $AZSYNC_SCRATCH;
}

sub wipe_scratch {
    $AZSYNC_SCRATCH = '';
    scratch();
}

sub bucket {
    my ($bucket) = @_;
    return "$AZSYNC_WD/t/files/azsync/$bucket";
}

sub azsync { # runs azsync --from $url --to $scratch
    my ( $bucket, %args ) = @_;

    my $scratch = scratch();
    my @azsync_opts = (
        "--curl",
        "--from" => "$AZSYNC_URL/$bucket",
        "--to"   => $scratch,
    );

    push @azsync_opts, "--external-verify" => $args{'external-verify'}
      if $args{'external-verify'};

    # cpargs hack on bsd4
    push @azsync_opts, "--cpargs" => "-Rp"
      if $^O eq 'freebsd' && `uname -r` =~ /^4.11/;

    {
        local $ENV{PATH} = "/var/chisel/bin:/usr/local/bin:/sbin:/usr/sbin:/bin:/usr/bin" if $ENV{chiselTEST_USESYSTEM};
        local $ENV{PERL5LIB} = "/var/chisel/lib/perl5/site_perl" if $ENV{chiselTEST_USESYSTEM};
        
        my @cmd =
          $ENV{chiselTEST_USESYSTEM}
          ? ( "/var/chisel/bin/azsync", "--rzsync" => "/var/chisel/bin/recursive-zsync", @azsync_opts )
          : ( "azsync", @azsync_opts );
        
        my $pid = open3( my $to_azsync, my $from_azsync, undef, @cmd ) or die;
        my $output = do { local $/; <$from_azsync> };

        close $to_azsync;
        close $from_azsync;
        waitpid $pid, 0; # sets $?

        return wantarray ? ( $?, $output ) : $?;
    };
}

sub azsync_ok {    # azsync $bucket into scratch, then confirm it worked
    my ( $bucket, %args ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $scratch = scratch();
    my ( $r, $out ) = azsync( $bucket, %args );

    my $message = $args{'message'} || "azsync fetched bucket '$bucket'";

    if( "$r" ne "0" ) { # nonzero exit: test failure
        fail($message);
        diag( "azsync exit status was $r, output was:\n$out" );
    } else { # zero exit: test succeeds assuming data directory has been correctly updated
        scratch_is( $bucket, "data directory has been updated", $message )
          or diag( "azsync exit status was $r, output was:\n$out" );
    }
}

sub azsync_dies {    # azsync $bucket into scratch, but expect it to fail
    my ( $bucket, %args ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $scratch = scratch();
    my $prescan = _scan( "$scratch/current" );
    my ( $r, $out ) = azsync( $bucket, %args );
    my $postscan = _scan( "$scratch/current" );

    my $message = $args{'message'} || "azsync failed as expected on $bucket";

    if( "$r" eq "0" ) { # zero exit: test failure
        fail($message);
        diag( "azsync exit status was $r, output was:\n$out" );
    } else { # nonzero exit: test succeeds assuming data directory was unmolested
        is( $postscan, $prescan, $message )
          or diag( "azsync exit status was $r, output was:\n$out" );
    }
}

sub scratch_is_gone {
    my ( $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $scratch = scratch();
    ok( ! -e "$scratch/current", $message || "scratch/current does not exist" );
}

sub scratch_is {
    my ( $bucket, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $message ||= "scratch matches bucket '$bucket'";

    my $scratch = scratch();
    chdir $scratch
      or do { diag( "can't chdir to scratch '$scratch': $!" ); fail( $message ); return };

    my $m_scratch = _scan( "$scratch/current" );
    my $m_bucket = _scan( bucket($bucket), ignore_azsync_md => 1 );

    is( $m_scratch, $m_bucket, $message );
}

sub scratch_isnt {
    my ( $bucket, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $message ||= "scratch differs from bucket '$bucket'";

    my $scratch = scratch();
    chdir $scratch
      or do { diag( "can't chdir to scratch '$scratch': $!" ); fail( $message ); return };

    my $m_scratch = _scan( "$scratch/current" );
    my $m_bucket = _scan( bucket($bucket), ignore_azsync_md => 1 );

    isnt( $m_scratch, $m_bucket, $message );
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

            # optionally skip azsync metadata
            return if $ignore_azsync_md && ( $absname eq './azsync.manifest.json' || $absname =~ m{^./azsync.data(?:/|$)} );

            # always skip svn stuff
            return if $absname =~ m{/\.svn};

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
