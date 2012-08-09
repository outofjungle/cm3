######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::Integrity;

use 5.006_001;
use strict;
use Carp;
use Cwd ();
use POSIX ();
use IPC::Open2 qw/open2/;
use IPC::Open3 qw/open3/;
use Chisel::Manifest;
use Fcntl;

sub new {
    my ( $class, %rest ) = @_;

    my $defaults = {
        bin_gpg             => '',
        bin_gpgv            => '',
        gnupghome           => '',
        verbose             => 0,
    };

    my $self = { %$defaults, %rest };

    if( keys %$self > keys %$defaults ) {
        confess "Too many parameters: " . join ", ", keys %$self;
    }

    bless $self, $class;
    $self->_findbin;
    return $self;
}

# check a directory manifest
# returns manifest location if good, undef (not die!) otherwise
sub verify_manifest {
    my ( $self, %args ) = @_;

    defined( $args{$_} )
      or confess "$_ not given" for qw/dir/;

    # Chisel::Manifest->validate dies on failure
    my $cwd = Cwd::getcwd;
    chdir $args{dir};
    my $r = eval {
        Chisel::Manifest->new->load_manifest( "MANIFEST" )->validate();

        1;
    };
    chdir $cwd;

    if( ! $r ) {
        warn "$@\n" if $self->{verbose};
        return undef;
    } else {
        return "$args{dir}/MANIFEST";
    }
}

# signs a string with GPG
# returns armored signature on success, dies on failure
sub sign {
    my ( $self, %args ) = @_;

    defined( $args{$_} )
      or confess "$_ not given" for qw/contents key/;

    my @cmd = (
        $self->{bin_gpg},
        "--homedir" => $self->{gnupghome},
        "--batch",
        "--yes",
        "--armor",
        "-o"        => "-",
        "-u"        => $args{key},
        "-b"        => "-",
    );

    my $pid = open2( my $fromgpg, my $togpg, @cmd );

    # send contents over gpg's stdin
    do {
        local $SIG{'PIPE'} = 'IGNORE';
        print $togpg $args{contents}
          or die "can't write to gpg: $!\n";
        close $togpg
          or die "can't close pipe to gpg: $!\n";
    };

    my $out = do { local $/; <$fromgpg> };

    close $fromgpg;
    waitpid $pid, 0; # sets $?

    if( $? ) {
        # something went wrong
        die "[FAIL] @cmd\n";
    } else {
        return $out;
    }
}

# check the GPG signature of a file
# returns 1 on good signature, undef (not die!) otherwise
sub verify_file {
    my ( $self, %args ) = @_;

    defined( $args{$_} )
      or confess "$_ not given" for qw/file key/;

    my $sigfile = "$args{file}.asc";
    my $ring = $args{ring} || "pubring.gpg";

    my @cmd = (
        $self->{bin_gpgv},
        "--keyring"   => $ring,
        "--status-fd" => 1,
        "--homedir"   => $self->{gnupghome},
        $sigfile,
        $args{file},
    );

    # from the gnupg distribution's DETAILS file:
    #
    #     GOODSIG   <long keyid>  <username>
    #     The signature with the keyid is good.  For each signature only
    #     one of the three codes GOODSIG, BADSIG or ERRSIG will be
    #     emitted and they may be used as a marker for a new signature.
    #     The username is the primary one encoded in UTF-8 and %XX
    #     escaped.

    my $ok;

    my ( $fromgpg, $togpg, $devnull );
    my $pid;

    if( $self->{verbose} ) {
        # let stderr pass through
        $pid = open2( $fromgpg, $togpg, @cmd );
    } else {
        # send stderr to /dev/null
        open DEVNULL, ">", "/dev/null"
          or die "open /dev/null: $!\n";
        $pid = open3( $togpg, $fromgpg, ">&DEVNULL", @cmd );
        close DEVNULL;
    }

    close $togpg; # we've got nothing to say

    my %good_signature;
    while( defined( my $gpgline = <$fromgpg> ) ) {
        if( $gpgline =~ /^\[GNUPG:\] GOODSIG\s+\S+\s+(\S+)/ ) {
            $good_signature{$1} = 1;
        }
    }

    close $fromgpg;
    waitpid $pid, 0; # sets $?

    # unfortunately the exit code will only be 0 if every signature is a GOODSIG, but
    # we want to accept the file even in some cases when it's not (it's ok to have extra
    # signatures that don't validate, as long as a minimum set does)
    #
    # so we can't check the exit code but we can at least check that it exited normally

    if( POSIX::WIFEXITED($?) ) {
        # check that %good_signature matches $args{key}

        my $ok;

        if( $args{key} =~ /^\*+$/ ) {
            # something like * or ** which means "any 1 key" or "any 2 keys"
            $ok = ( scalar keys %good_signature >= length $args{key} );
        } else {
            # look for this key name verbatim
            $ok = scalar grep { $_ eq $args{key} } keys %good_signature;
        }

        return $ok ? 1 : undef;
    }

    else {
        warn "[FAIL] @cmd\n" if $self->{verbose};
        return undef;
    }

    # shouldn't be reached, but...
    return undef;
}

# look for gpg and gpgv if they aren't already found
sub _findbin {
    my ( $self ) = @_;

    # attempt to find a gpg binary
    $self->{bin_gpg} ||= $self->_findbin_helper( "gpg" ) || $self->_findbin_helper( "gpg2" ) || "gpg";

    # attempt to find a gpgv binary
    $self->{bin_gpgv} ||= $self->_findbin_helper( "gpgv" ) || $self->_findbin_helper( "gpgv2" ) || "gpgv";
}

# look for a binary
sub _findbin_helper {
    my ( $self, $bin ) = @_;

    my $f;

       eval { -x ( $f = "/var/chisel/bin/$bin" ); }
    || eval { chomp( $f = qx[which $bin 2>/dev/null] ) && -x $f; }
    || eval { $f = undef; };

    return $f;
}

1;
