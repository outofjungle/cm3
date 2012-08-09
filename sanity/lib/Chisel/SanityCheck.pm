######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::SanityCheck;

use strict;
use warnings;
use Carp;
use Getopt::Long qw/:config require_order gnu_compat/;
use File::Basename qw/fileparse/;
use Fcntl;

use Exporter qw/import/;
our @EXPORT_OK = qw/args read_file check_files/;
our %EXPORT_TAGS = ( "all" => [@EXPORT_OK], );

sub args { # implements the spec for sanity checks
    my %args = @_;

    my %o;
    usage() unless GetOptions(\%o, "F|file", "S|script");

    my $file = shift @ARGV;
    usage() unless defined $file;

    if( $o{F} ) {
        # file-mode, we should return the list
        return () if ! -e $file;

        my %files;
        opendir my $fd, $file
          or die "could not opendir $file: $!";
        $files{$_} = "$file/$_" for grep { ! /^\./ } readdir $fd;
        closedir $fd;

        return %files;
    }
    elsif( $o{S} ) {
        # script-mode, we should check that it exists
        check_script(
            filename => $file,
            # lang     => $args{script_lang},
            # cmd      => $args{script_test},
        );

        exit 0;
    }
    else {
        # nothing to do?
        usage();
    }
}

sub usage {
    warn "Usage: $0 [-S|-F] file\n";
    exit 1;
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

# perform checks on the set of files for this module
sub check_files {
    my %args = @_;
    defined($args{$_}) or confess "$_ not given"
      for qw/files/;

    my %files = %{$args{files}};

    if( $args{min} ) { # minimum set
        my @fails = grep { !$files{$_} } @{$args{min}};
        die "missing files: @fails\n" if @fails;
    }

    if( $args{max} ) { # maximum set
        my %max = map { $_ => 1 } @{$args{max}};
        my @fails = grep { !$max{$_} } keys %files;
        die "extra files: @fails\n" if @fails;
    }

    return 1;
}

sub check_script {
    my %args = @_;
    defined($args{$_}) or confess "$_ not given"
      for qw/filename/;

    # default language is perl
    # my $lang = $args{lang};
    # $lang = 'perl' if ! defined $lang; # but if it's just "", leave it be

    my ($s, $path) = fileparse( $args{filename} );

    # check existence
    if( ! -e "$path/$s" ) {
        die "Script missing: $s";
    }

    # per-language check
    # if( $lang eq 'perl' || $lang eq 'pl' ) {
    #     my $r = qx[cd $path && /usr/bin/perl -I /lib/perl5/site_perl/5.8 -Mstrict -wc ./$s 2>&1];
    #     if( $? != 0 ) {
    #         die "Script failed $lang check: $s\n$r";
    #     }
    # }
    # elsif( $lang ) {
    #     die "Don't know how to check language: $lang";
    # }

    # custom check
    # if( $args{cmd} ) {
    #     my @cmd = ref $args{cmd} eq 'ARRAY' ? @{ $args{cmd} } : ( $args{cmd} );
    #     my $r = system(@cmd);
    #
    #     if( $r != 0 ) {
    #         die "Script failed custom check:\nRAN: [@cmd]";
    #     }
    # }

    return 1;
}

1;
