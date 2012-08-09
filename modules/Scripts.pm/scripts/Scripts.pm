######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


#!/usr/bin/perl -w

######################################################################
#  Copyright (c)2011, Yahoo!, Inc.
#
######################################################################

=head1 NAME

Scripts - Building blocks for configuration modules

=head1 SYNOPSIS

    use Scripts qw/:all/;

    my $provided_file = args();

    my $etchosts = read_file( filename => "/etc/hosts" );

    write_file(
        contents => "stuff\n",
        filename => "/etc/stuff",
    );

    install_file(
        from     => $provided_file,
        to       => "/etc/otherstuff",
        template => 0,
    );


=head1 ENVIRONMENT

 Scripts.pm looks out for some environment variables in order to
tune its behavior at runtime.

    chisel_RECONFIGURE_ONLY - Do not attempt any servce start/stop
                           operations.  Set by chisel_install.

    CHISEL_DRY_RUN - Do not attempt any execution or modification
                  operations.  Display messages indicating what would
                  be done instead.

=cut


package Scripts;
use strict;
use Getopt::Long qw/:config require_order gnu_compat/;
use File::Path;
use File::Basename;
use Sys::Hostname;
use Socket;
use Fcntl;
require "sys/syscall.ph";

use base qw/Exporter/;
our @EXPORT_OK = qw/args get_my_ip get_hostname get_os get_os_ver get_redhat_release install_file read_file write_file chmod_file chown_file unlink_file rename_file symlink_file mkdir_path restart_cmd dryrun/;
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );
our @EXPORT = ();

sub logentry {
    for (@_) {
        print STDERR time . "$0:" . get_hostname() . $_ . "\n";
    }
}

sub dryrun {
    print STDERR "DRYRUN: $0 WOULD: ", join( " ", @_ ), "\n";  # Clean as long as @_ doesn't contain \n...
}


sub args {
    my %args = @_;
    $args{interval} = 300 if !$args{interval} || $args{interval} < 300;

    my %opt = ( 'interval' => "Interval to wait after running",
                'h|help'   => "Display this help" );

    my %o;
    usage(undef,%opt) unless GetOptions(\%o, keys %opt);
    usage(undef,%opt) if($o{h});
    if($o{interval}) {
        my $wait = int( $args{interval} + rand( $args{interval} * 0.10 ) );
        print "$wait\n";
        exit 0;
    }

    # $ARGV[0] will contain directory to operate in. grab and untaint it.
    my $dir = shift @ARGV;
    ( $dir ) = ( $dir =~ /^(.*)$/ );

    usage(undef,%opt) unless($dir);
    usage("$dir does not exist") unless(-d $dir);

    my %files;
    opendir my $fd, $dir or die "could not opendir $dir: $!";

    foreach my $dirf (readdir $fd) {
        # confirm format and untaint
        if( $dirf =~ /^([a-zA-Z0-9][a-zA-Z0-9\.\-\_]{0,63})$/ ) {
            $files{$dirf} = "$dir/$1";
        }
    }

    closedir $fd;

    if( wantarray ) { # read dir
        return %files;
    } else { # read single file
        return $files{ $args{file} || "MAIN" };
    }
}

sub install_file {
    my %args = @_;
    defined($args{$_}) or die "$_ not given"
      for qw/from to/;

    my $read = read_file(filename => $args{from});

    return write_file(filename  => $args{to},
                      contents  => $read,
                      mode      => $args{mode},
                      template  => $args{template},
                      cmd       => $args{cmd},
                      pretest   => $args{pretest},
                      test      => $args{test});
}

sub read_file {
    my %args = @_;
    defined($args{$_}) or die "$_ not given"
      for qw/filename/;

    my $filename = $args{filename};
    sysopen my $fh, $filename, O_RDONLY
      or die "open $filename: $!\n";

    my $size = -s $filename || (1024<<10); # for /proc files

    my $results = "";
    while (1) {
        my $read = sysread $fh, $results, $size, length $results;

        if( ! defined $read ) { # error
            die "read $filename: $!\n";
        } elsif( $read == 0 ) { # eof
            last;
        } else { # more to read
            $size -= $read;
            last if $size <= 0;
        }
    }

    close $fh;
    return $results;
}

sub write_file {
    my %args = @_;

    defined($args{$_}) or die "$_ not given"
      for qw/filename contents/;

    my $contents = $args{contents};

    # Expand template vars
    if($args{template}) {
        $contents = expand_vars($contents);
    }

    # Create directories if necessary
    my $dir = (fileparse($args{filename}))[1];
    chop $dir if ($dir =~ /\/$/);
    eval { mkpath($dir, 0, 0755) };
    die "mkdir $dir: $@" if ($@);

    # Write the data to a temporary file, and sync the file to disk
    my $tempfile = $args{filename} . ".secotemp.$$";
    {
        # refuse to write to an already-existing file
        # and honor permissions mode we were asked for
        my $mode = defined $args{mode} ? $args{mode} : 0644;
        sysopen my $fh, $tempfile, O_CREAT | O_EXCL | O_WRONLY, $mode
          or die "open $tempfile: $!\n";

        { my $ofh = select $fh;
          $| = 1;
          select $ofh;
        }

        print $fh $contents
          or die "print $tempfile: $!\n";
        my $ret = syscall &SYS_fsync, fileno $fh;
        if (-1 == $ret) {
            unlink $tempfile;
            die "Can't fsync $tempfile, aborting";
        }
        close $fh
          or die "close $tempfile: $!";
    }

    {
        # Check to ensure data was written correctly
        # by reading it back

        my $tempcontents = read_file( filename => $tempfile );
        die "error: data written doesn't match data in temp file"
          unless $tempcontents eq $contents;
    }

    if( -e $args{filename} ) {
        # Check to see if we should apply this new file
        system("diff", "-u", $args{filename}, $tempfile);
        unless($?>>8) {
            unlink $tempfile;
            return 0;
        }
    }

    # Run pretest if asked
    if( $args{pretest} ) {
        my $tempfile_quote = quotemeta $tempfile;

        my $pretest = $args{pretest};
        $pretest =~ s/(\s)\{\}(\s|$)/$1$tempfile_quote$2/g;

        print "[RUN] $pretest\n";
        system('sh', '-c', $pretest);
        if($?) { # failed pretest
            unlink $tempfile;
            die "failed pretest: $pretest\n";
        }
    }

    # Save the old file if we're doing a test
    my $savefile = "$args{filename}.backup.$$";
    if( $args{test} ) {
        if( lstat $args{filename} ) { # current file is on disk
            unless(link $args{filename} => $savefile) { # could not save current file
                unlink $tempfile;
                die "link $args{filename} to $savefile: $!";
            }
        } else { # current file doesn't exist, so null out $savefile
            undef $savefile;
        }
    }

    if( ! $ENV{'CHISEL_DRY_RUN'} ) {
        # Rename the tempfile into the final location
        unless(rename $tempfile => $args{filename}) { # error; clean up
            unlink $tempfile;
            unlink $savefile if $args{test} && defined $savefile;
            die "rename $tempfile to $args{filename}: $!";
        }
    } else {
        dryrun( "replace original file with new version" );
        # clean up...
        unlink $tempfile;
        unlink $savefile if $args{test} && defined $savefile;
    }

    # Postinstall commands
    if( $args{cmd} ) {
        if( ! $ENV{'CHISEL_DRY_RUN'} ) {
            print "[RUN] $args{cmd}\n";
            system('sh', '-c', $args{cmd});
        } else {
            dryrun( "run cmd: " . $args{cmd} );
        }
    }

    # Run tests
    my $rollback = 0;
    if( $args{test} ) {
        if( ! $ENV{'CHISEL_DRY_RUN'} ) {
            print "[RUN] $args{test}\n";
            system('sh', '-c', $args{test});
            if($?) {
                # restore original
                if( defined $savefile ) {
                    rename $savefile => $args{filename}
                      or $rollback = -1;
                } else {
                    unlink $args{filename}
                      or $rollback = -1;
                }

                # run postinstall again
                if( $args{cmd} ) {
                    print "[RUN] $args{cmd}\n";
                    system('sh', '-c', $args{cmd});
                }

                $rollback ||= 1;
            } elsif( defined $savefile ) {
                # remove original
                unlink $savefile;
            }
        } else {
            dryrun( "run test: " . $args{test} );
        }
    }

    # (Linux only) Fsync the directory to ensure the dirent is
    # on disk as well -- see fsync(2)
    if( ! $ENV{'CHISEL_DRY_RUN'} ) {
        open my $fh, $dir or die "$dir: $!";
        syscall &SYS_fsync, fileno $fh;
        close $fh;

        # $rollback should automatically be 0 in dry run, but we'll enclose this anyway
        if( $rollback == -1 ) {
            die "test failed, but could not roll back file";
        } elsif( $rollback ) {
            die "test failed, rolled back file";
        }
    }

    return 1;
}

sub chmod_file {
    my( $permissions, $filename ) = @_;

    defined($filename) or die "filename not given";
    defined($permissions) or die "permissions not given";

    if( ! $ENV{'CHISEL_DRY_RUN'} ) {
        return chmod $permissions => $filename;
    } else {
        if( -e $filename ) {
            my $fileperms = ( stat( $filename ) )[2] & 07777;
            dryrun( "chmod $permissions => $filename" )
                if( $fileperms != $permissions );
        }
    }
    
    return 1;
}

sub chown_file {
    my( $uid, $gid, $filename ) = @_;

    defined($uid) or die "uid not given";
    defined($gid) or die "gid not given";
    defined($filename) or die "filename not given";

    if( ! $ENV{'CHISEL_DRY_RUN'} ) {
        return chown $uid, $gid, $filename;
    } else {
        if( -e $filename ) {
            my( $file_uid, $file_gid ) = ( stat( $filename ) )[4,5];
            dryrun( "chown $uid, $gid, $filename" )
                if( $file_uid != $uid or $file_gid != $gid );
        }
    }
    
    return 1;
}

sub unlink_file {
    my( $filename ) = @_;

    defined($filename) or die "filename not given";

    if( ! $ENV{'CHISEL_DRY_RUN'} ) {
        return unlink $filename;
    } else {
        # Note we only check for existence, not permissions or type
        if( -e $filename ) {
            dryrun( "unlinking $filename" );
        }
    }
    
    return 1;
}

sub rename_file {
    my( $oldname, $newname ) = @_;

    defined($oldname) or die "oldname not given";
    defined($newname) or die "newname not given";

    if( ! $ENV{'CHISEL_DRY_RUN'} ) {
        return rename $oldname => $newname;
    } else {
        # Note we only check for existence, not permissions or type
        if( -e $oldname ) {
            dryrun( "rename $oldname => $newname" );
        }
    }

    return 1;
}

sub symlink_file {
    my( $target, $link ) = @_;

    defined($target) or die "target not given";
    defined($link) or die "link not given";

    if( ! $ENV{'CHISEL_DRY_RUN'} ) {
        return symlink $target => $link;
    } else {
        dryrun( "symlink $target => $link" );
    }

    return 1;
}

sub mkdir_path {
    my( $directory, $mask ) = @_;

    defined($directory) or die "directory not given";
    defined($mask) or die "mask not given";

    my $printable_mask = sprintf( "%o", $mask );

    if( ! $ENV{'CHISEL_DRY_RUN'} ) {
        return mkdir $directory, $mask;
    } else {
        dryrun( "mkdir $directory $printable_mask" )
          if( ! -e $directory );
    }

    return 1;
}

sub restart_cmd {
    my %args = @_;

    # name of the service
    my $service = $args{service}
      or die "what service?";

    # dummy mode
    if( $ENV{'chisel_RECONFIGURE_ONLY'} ) {
        return "true";
    }

    # daemontools
    elsif( -d "/service/$service" ) {
        return "svc -t /service/$service";
    }

    # rc script in /etc/init.d
    elsif( -x "/etc/init.d/$service" ) {
        # check for /sbin/service
        if( -x "/sbin/service" ) {
            return "/sbin/service $service restart";
        } else {
            return "/etc/init.d/$service restart";
        }
    }

    # rc script in /etc/rc.d
    elsif( -x "/etc/rc.d/$service" ) {
        return "/etc/rc.d/$service restart";
    }

    # pidfile in /var/run -- can only be used for reloading
    # since we don't really know how to start a new instance of this service
    elsif( $args{reload_ok} && -r "/var/run/$service.pid" ) {
        return "kill -HUP `cat /var/run/$service.pid`";
    }

    return undef;
}

sub expand_vars {
    my $content = shift;

    for ($content) {
    # get_ functions are cached, so only call if we really use them
    # only the first call is expensive
	    s/::hostname::/get_hostname()/ge;
        s/::shortname::/cache_shortname()/ge;
        s/::shorthostname::/cache_shortname()/ge;
        s/::ip::/get_my_ip()/ge;
    }

    return $content;
}

# closures for needless optimization
{
    my $_hostname;
    my $_shortname;
    my $_ip;
    my $_os;
    my $_os_ver;
    sub get_hostname {
        return $_hostname if $_hostname;
        return $_hostname = Sys::Hostname::hostname();
    }
    sub cache_shortname {
        return $_shortname if $_shortname;
        ($_shortname) = split(/\./, get_hostname(), 2);
        return $_shortname;
    }
    sub get_my_ip {
        return $_ip if $_ip;

        my $ifconfig = `ifconfig -a`;
        $ifconfig =~ s/\n / /g;
        my @ifconfig = split(/\n/,$ifconfig);

        foreach ( @ifconfig ) {
            # FIXME: If FreeBSD ever has an interface type 'eth' it will be ignored

            next if( /^lo/ );                                                                          # Don't want loopbacks
            next if( /LOOPBACK/ );                                                                     # Don't want loopbacks
            next if( /inet addr:127\./ || /inet 127\./ );                                              # Don't want loopbacks
            next if( /^eth\d:/ );                                                                      # Don't want vips
            next if( /inet addr:10\./ || /inet 10\./ );                                                # Don't want RFC 1918
            next if( ( /inet addr:172\.(\d+)/ || /inet 172\.(\d+)/ ) && ( $1 >= 16 && $1 <= 31 ) );    # Don't want RFC 1918
            next if( /inet addr:192\.168/ || /inet 192\.168/ );                                        # Don't want RFC 1918
            next if( /inet addr:169\.254/ || /inet 169\.254/ );                                        # Don't want RFC 3927
            if( /inet addr:(\S+)/ || /inet ([\d\.]+)/ ) {
                return $_ip = $1;
            }
        }
        return undef;
    }
    sub get_os {
        return $^O;
    }
    sub get_os_ver {
        return $_os_ver if $_os_ver;
        chomp($_os_ver = qx/uname -r/);
        return $_os_ver;
    }
    sub get_redhat_release {
        my $rr = read_file (filename => '/etc/redhat-release');
        if ($rr =~ /Red Hat Enterprise Linux AS release (\d) \(Nahant Update (\d)\)/) {
            return "$1.$2";
        }
        if ($rr =~ /Red Hat Enterprise Linux Server release (\d.\d)/) {
            return $1;
        }
    }
}

sub usage {
    my $msg = shift;
    my %opt = @_;
    $msg = "\n$msg\n" if($msg);
    $msg ||= '';

    print "Usage: $0 [options]\n";

    my @array;
    foreach my $key (keys %opt) {
        my ($left, $right) = split /[=:]/, $key;
        my ($a, $b) = split /\|/, $left;
        if($b) {
            $left = "-$a, --$b";
        } else {
            $left = "    --$a";
        }
        $left = substr($left . (' 'x20), 0, 20);
        push @array, "$left $opt{$key}\n";
    }

    print sort @array;
    die "$msg\n";
}

1;

__END__

=head1 DESCRIPTION

=head2 args

    my $file = args();                   # gets path to 'MAIN'
    my $file = args( file => "linux" );  # gets path to 'linux'
    my $file = args( interval => 3600 ); # override default interval of 300
    my %file = args();                   # $file{ short name } = path

Implements the spec for scripts. Scripts are normally invoked using:

    chdir "/var/chisel/data"
    fork and exec "scripts/SCRIPTNAME" "files/SCRIPTNAME"

Under such conditions, scripts should run using the files provided over the
command line.

Scripts should print on stdout C<INTERVAL\n> when run with the argument
C<--interval>.  C<INTERVAL> must consist of an integer value representing the
number of seconds the script would like to sleep before being executed
again.  Scripts are encouraged to randomize this value.

=back

=head2 read_file

    read_file( filename => "/path/to/file" );

Reads a file and returns its contents as a string. Dies on failure.

=head2 write_file

    write_file( contents => $str, filename => "/path/to/file" );

Safely writes to a file, creating a path leading up to the file if necessary. Returns true if the
file was changed, false if it did not need to be changed, and dies on failure. Optional arguments
include:

=over

=item

C<mode> -- file creation mode. Default is C<0644>.

=item

C<template> -- replace template vars like C<::hostname::> and C<::ip::>. Default is no.

=item

C<pretest> -- optional command to run against the new file before installing it. Will be run using C<sh>.
The name of the new file will replace C<{}>; for example, C<pretest => "visudo -cf {}"> will run the test
C<visudo -cf /path/to/temporary_new_file>.

=item

C<cmd> -- optional command to run after installing a new file. Will be run using C<sh>. Failures will
be ignored.

=item

C<test> -- optional test to run after installing a new file. Will be run using C<sh>. If the test fails,
the file will be rolled back, C<cmd> (if provided) will be run again, and then C<write_file> will die.

=back

=head2 install_file

    install_file( from => "/source/file", to => "/target/file" );

Shortcut for C<read_file> followed by C<write_file>. Shares the same options as C<write_file>.

=head2 restart_cmd

    $cmd = restart_cmd( service => "autofs" );
    $cmd = restart_cmd( service => "sshd", reload_ok => 1 );

Returns our best guess at how to restart C<service>, or undef if we really have no idea.

Add C<reload_ok> if you'd like to entertain the idea of not restarting the service but possibly just sending
it a HUP signal. This will only be done if the script can't figure out how to restart the service.

=cut
