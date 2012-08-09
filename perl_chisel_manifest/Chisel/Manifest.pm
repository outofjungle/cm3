######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::Manifest;

use warnings;
use strict;
use File::Find qw();
use Data::Dumper;
use Chisel::Manifest::File;
use JSON::PP qw();
use File::Spec;

# change this format
our %defaults = (
                 emit_keys => [qw/name md5 uid gid mtime type mode link/],
                 include_types => { file => 1, link => 1, },
                 validate_extra_files => 1,
                );

# obj holds state about what params to generate in a Chisel::Manifest::File

sub new {
    my ($class, $opts) = @_;
    warn 'non-hashref value for opts' if $opts and ref $opts ne "HASH";
    my $self = bless {
                      %defaults,
                      ref $opts eq "HASH" ? %$opts : (),
                     }, $class;
    return $self;
}

sub to_struct {
    my ($self) = @_;
    my $struct = [];
    for my $entry (@{$self->{computed_manifest}}) {
        # filter / verify keys
        my $emit_entry;
        for my $k (@{$self->{emit_keys}}) {
            $emit_entry->{$k} = $entry->{data}{$k}
              if defined $entry->{data}{$k};
        }
        push @$struct, $emit_entry;
    }
    return $struct;
}

sub to_json_lines {
    my ($self) = @_;
    my $output = "";
    my $struct = $self->to_struct();
    for my $emit_entry (@{$struct}) {
        # print $emit_entry->to_json;
        my $json = JSON::PP->new->ascii->allow_nonref->convert_blessed;
        $output .= $json->encode($emit_entry);
        $output .= "\n";
    }
    return $output;
}

sub load_manifest_data {
    my ($self, $data) = @_;
    open my $fh, "<", \$data or die "can't open data: $!";
    $self->load_manifest_fd($fh);
}

sub load_manifest {
    my ($self, $file) = @_;
    $self->load_manifest_file($file);
}
sub load_manifest_fd {
    my ($self, $fh) = @_;
    my @files;
    while (my $json = <$fh>) {
        my $href = JSON::PP::decode_json($json);
        my $file = new Chisel::Manifest::File {data => $href, debug => $self->{debug}};
        push @files, $file;
    }
    $self->{computed_manifest} = [@files];
    return $self;
}
sub load_manifest_file {
    my ($self, $file) = @_;
    open my $fh, "<", $file or die "can't open $file: $!";
    $self->load_manifest_fd($fh);
}

# for every Manifest::File, enforce->() it
sub enforce {
    my ($self) = @_;
    for my $mf (@{$self->{computed_manifest}}) {
        $mf->enforce();
    }
}

# check if our manifest contains this file object
# using Chisel::Manifest::compare_one over each of our entries
sub contains_entry {
    my ($self, $entry, $valid_keys) = @_;
    my $found = 0;
    for my $mentry ( @{ $self->{computed_manifest} } ) {
        if ($entry->compare_entries($mentry, $valid_keys)) {
            $found=1;
            last;
        }
    }
    return $found;
}

# given a path, find any files not in the manifest
# in this path
# $opts is a href of options for the filter
# assume cwd
# opts => types is a list of valid file types to complain about
# default is $self->include_types = link file

sub extra_files {
    my ($self, $opts) = @_;
    $opts = {} unless ref $opts eq 'HASH';
    $opts->{check_types} ||= $self->{include_types};
    my $path = $opts->{path};
    $path ||= ".";
    my @path_names = sort (_files_in_path($path));
    my %manifest = map { File::Spec->canonpath("$path/$_") => 1 } sort $self->names_in_manifest;
    $manifest{File::Spec->canonpath("$path/azsync.manifest.json")} = 1;
    @path_names = grep { not $manifest{$_} } @path_names;

    @path_names = grep {
        -l and $opts->{check_types}{link}
          or
        -f and $opts->{check_types}{file}
          or
        -d and $opts->{check_types}{dir}
          or
        -p and $opts->{check_types}{fifo}
          or
        -S and $opts->{check_types}{socket}
          or
        -b and $opts->{check_types}{block}
          or
        -c and $opts->{check_types}{char}
      } @path_names;
    return @path_names;
}

# given a path, find any directories not in the manifest
# in this path
# $opts is a href of options for the filter
# assume cwd

sub extra_dirs {
    my ($self, $opts) = @_;
    $opts = {} unless ref $opts eq 'HASH';
    my $path = $opts->{path};
    $path ||= ".";
    my %manifest = map { File::Spec->canonpath("$path/$_") => 1 } sort $self->names_in_manifest;
    my @maybe_extras = grep { ! -l $_ && -d $_ } (_files_in_path($path));
    my @extras;
    for my $maybe_extra (@maybe_extras) {
        my $qn = quotemeta $maybe_extra;
        push @extras, $maybe_extra if ! grep m{^$qn/}, keys %manifest;
    }
    return @extras;
}

sub names_in_manifest {
    my ($self) = @_;
    my @names;
    for my $mf (@{$self->{computed_manifest}}) {
        push @names, $mf->names;
    }
    return @names;
}

sub validate {
    my ($self, $opts) = @_;
    $opts = {} unless ref $opts eq 'HASH';
    for my $mf (@{$self->{computed_manifest}}) {
        $mf->validate();
    }
    if ($self->{validate_extra_files}) {
        my @extra = $self->extra_files;
        die "found extra files: @extra" if @extra;
    }
}

sub add_files {
    my ($self, @files) = @_;
    for my $file (@files) {
        # Get the file's device & inode and bucket accordingly
        my @stat = lstat $file or die "can't lstat $file, : $!";
        push @{ $self->{files_by_inode}{"$stat[0].$stat[1]"} }, $file;
    }
    return $self;
}

sub _files_in_path {
    my ($path) = @_;
    my @files;
    File::Find::find( sub {
                          push @files, $File::Find::name
                            unless $File::Find::name eq '.'
                              or $File::Find::name eq '..';
                      }, $path );
    @files = map {File::Spec->canonpath($_)} @files;
    return @files;
}
sub add_dir {
    my ($self, $path) = @_;
    my @files = _files_in_path($path);
    $self->add_files(@files);
}

sub compute_manifest {
    my ($self) = @_;
    my @files = values %{ $self->{files_by_inode} };
    # we assume a uniform sort order between manifests
    # for the name lists
    @files = sort {$a->[0] cmp $b->[0]} @files;
    @files  = map {new Chisel::Manifest::File {data => {name => $_}} } @files;
    for my $file (@files) {
        $file->populate;
    }
    @files = grep { $self->{include_types}->{$_->{data}{type}} } @files;
    $self->{computed_manifest} = [@files];
    return $self;
}

1;

__END__

=pod

=head1 NAME

  Chisel::Manifest - create, validate and apply extensible manifest files

=head1 SYNOPSIS

  Chisel::Manifest manages a manifest of multiple files -- by default representing a
  directory subtree.

  Chisel::Manifest::File is a class handling individual entries in the manifest.

=head1 EXAMPLES

=head2 Create a manifest of the current directory tree

  my $m = new Chisel::Manifest;
  $m->add_dir(".");
  $m->compute_manifest;
  print $m->to_json_lines();

=head2 Validate a manifest against the current directory tree

  my $m = new Chisel::Manifest;
  $m->load_manifest("manifest.json");
  # $m->enforce; # chmod, chown, etc.
  $m->validate;

=head1 AUTHOR

  Evan Miller <eam@yahoo-inc.com>

=cut

