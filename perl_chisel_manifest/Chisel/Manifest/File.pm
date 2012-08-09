######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::Manifest::File;

use warnings;
use strict;
use Digest::MD5;
use JSON::PP qw();

our %defaults =
  (
   get_keys => [ qw/uid gid mode type mtime md5/ ], # order matters
   set_keys => [ qw/uid gid mode mtime/ ], # order matters, mtime last
   validate_keys => [ qw/uid gid mode type mtime md5 link / ], # no needed ordering
  );


sub new {
    my ($class, $opts) = @_;
    warn 'non-hashref value for opts' if $opts and ref $opts ne "HASH";
    my $self = bless {
                      %defaults,
                      ref $opts eq "HASH" ? %$opts : (),
                     }, $class;
    return $self;
}

# in the case of a manifest entry with multiple links
# we often only want one name to reduce work
sub first_name {$_[0]->{data}{name}->[0]};
sub names { @{ $_[0]->{data}{name} } };

# get takes file name (file obj), returns value for key

use Data::Dumper;

# return 0 if they don't match
# return 1 if they do
sub compare_entries {
    my ($self, $other, $valid_keys) = @_;
    my $self_data = { %{$self->{data}} };
    my $other_data = { %{$other->{data}} };
    if (ref $valid_keys eq 'ARRAY') {
        my %vk_map = map { $_ => 1 } @$valid_keys;
        my @temp_keys = keys %$self_data; # dodge hash iterator issues
        for my $k (@temp_keys) {
            delete $self_data->{$k} unless exists $vk_map{$k};
        }
        @temp_keys = keys %$other_data;
        for my $k (@temp_keys) {
            delete $other_data->{$k} unless exists $vk_map{$k};
        }
    }
    # same number of keys
    return 0 unless keys %$self_data == keys %$other_data;
    # and for all keys in A there is a key in B with the same value
    for my $k (keys %{$self_data}) {
        return 0 unless exists $other_data->{$k};
        if ($k eq 'name') {
            # same number of entries
            return 0 unless @{$self_data->{name}} == @{$other_data->{name}};
            # assume identical sort order
            for my $i (0..$#{$self_data->{name}}) {
                return 0 unless $self_data->{name}[$i] eq $other_data->{name}[$i];
            }
        } else {
            # generic for all non-complex values
            return 0 unless $self_data->{$k} eq $other_data->{$k};
        }
    }
    # if we got here, they match
    return 1;
}

sub to_json {
    my ($self) = @_;
    my $json = JSON::PP->new->ascii->allow_nonref->convert_blessed;
    return $json->encode($self->{data});
}

sub stat_cache {
    my ($self) = @_;
    return $self->{stat_cache} if $self->{stat_cache};
    my @stat = lstat $self->first_name
      or die "couldn't lstat: $!";
    $self->{stat_cache} = [@stat];
    return $self->{stat_cache};
}

# call get_$key for every key in get_keys
sub populate {
    my ($self) = @_;
    for my $key (@{$self->{get_keys}}) {
        next if $key eq "link";
        my $method = "get_".$key;
        $self->{data}{$key} = $self->$method;
    }
    if (exists $self->{data}{type} and
        $self->{data}{type} eq "link") {
        $self->{data}{link} = $self->get_link();
    }
}


# call check_key for every key in check_keys
# fix this, we want to validate the internal structure of $self
# * all links point to 1 inode
# * md5 matches file data
# stat() data matches stat() keys
sub validate {
    my ($self) = @_;
    for my $key (@{$self->{validate_keys}}) {
        next unless $self->{data}{$key};
        my $method = "get_".$key;
        my $want = $self->{data}{$key};
        my $is = $self->$method; # get the current value
        die "can't validate entry for " . $self->first_name .
          " on key $key. Wanted $want got $is"
            unless $is eq $want;
        # need func for extra files finding
    }
    # also check to verify all names are same links
    warn "signing off on " . $self->first_name if $self->{debug};
}

# call set_key for every key in set_keys
# and name this better
sub enforce {
    my ($self) = @_;
    for my $key (@{$self->{set_keys}}) {
        next unless $self->{data}{$key};
        my $method = "set_".$key;
        $self->$method; # die on failure, sets file metadata
    }
    warn "enforced ".$self->first_name." ok" if $self->{debug};
}

# names must be given
#sub get_name {
#}

sub get_link {
    my ($self) = @_;
    my $readlink = readlink $self->first_name
      or die "couldn't readlink: $!";
    return $readlink;
}
sub get_type {
    my ($self) = @_;
    # could implement with Fcntl stuff to read stat mode
    # but it's probably more compatible to use Perl's builtins
    local $_ = $self->first_name;
    if (-l) { return "link"; }
    elsif (-d) { return "dir" }
    elsif (-p) { return "fifo" }
    elsif (-S) { return "socket" }
    elsif (-b) { return "block" }
    elsif (-c) { return "char" }
    elsif (-f) { return "file"; }
    else { die "unknown file type: $_" }
}

sub get_uid {
    my ($self) = @_;
    return $self->stat_cache->[4];
}

sub get_gid {
    my ($self) = @_;
    return $self->stat_cache->[5];
}

sub get_size {
    my ($self) = @_;
    return $self->stat_cache->[7]
}

sub get_atime {
    my ($self) = @_;
    return $self->stat_cache->[8];
}
sub get_mtime {
    my ($self) = @_;
    return $self->stat_cache->[9];
}
sub get_ctime {
    my ($self) = @_;
    return $self->stat_cache->[10];
}

sub get_mode {
    my ($self) = @_;
    my $mode = sprintf '%04o', ($self->stat_cache->[2] & 07777);
    return $mode;
}

sub get_md5 {
    my ($self) = @_;
    return undef unless $self->{data}{type} eq "file"; # only md5 plain files
    my $md5 = Digest::MD5->new;
    open my $fh, $self->first_name or die "can't open ".$self->first_name.": $!";
    binmode $fh;
    $md5->addfile($fh);
    my $digest = $md5->hexdigest;
    close $fh;
    return $digest;
}


sub set_mode {
    my ($self) = @_;
    return undef if $self->{data}{type} eq "link";
    chmod oct($self->{data}{mode}), $self->first_name
      or die "can't chmod: $!";
}

sub set_uid {
    my ($self) = @_;
    return undef if $self->{data}{type} eq "link";
    chown $self->{data}{uid}, $self->{data}{gid}, $self->first_name
      or die "can't chown ".$self->first_name.": $!";
    warn "set uid on ". $self->first_name . " to ". $self->{data}{uid}
      if $self->{debug};
}

sub set_gid {
    my ($self) = @_;
    $self->set_uid($self);
}

sub set_mtime {
    my ($self) = @_;
    return undef if $self->{data}{type} eq "link";
    my $atime = $self->{data}{atime};
    $atime ||= $self->{data}{mtime};
    utime $atime, $self->{data}{mtime}, $self->first_name
      or die "can't utime: $!";
}

sub set_atime {
    my ($self) = @_;
    $self->set_mtime;
}

sub set_md5 {
    die "can't apply a checksum";
}

sub set_link {
    my ($self) = @_;
    unlink $self->{data}{first_name};
    symlink $self->{data}{"link"}, $self->{data}{first_name};
}

1;

