######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::Bucket;

use warnings;
use strict;
use Digest::SHA1 qw/sha1_hex/;
use File::Find ();
use JSON::XS ();
use Hash::Util ();
use Log::Log4perl qw/:easy/;
use Regexp::Chisel qw/:all/;
use Carp;

# print our name when used as a string
use overload '""'  => sub { shift->tree };
use overload 'cmp' => sub { my ( $x, $y, $flip ) = @_; $flip ? "$y" cmp "$x" : "$x" cmp "$y" };

sub new {
    my ( $class, %rest ) = @_;

    my $defaults = {
        loadable => undef,    # set this to a sub that returns files, if this bucket should be lazy loadable
    };

    my $self = { %$defaults, %rest };
    if( keys %$self > keys %$defaults ) {
        LOGDIE "Too many parameters, expected only " . join ", ", keys %$defaults;
    }

    bless $self, $class;

    # set up a new manifest
    $self->{manifest} = {};

    # all directories that are implied by files in this bucket
    # the purpose is to make ->add reject conflicts between files and directories
    $self->{dir} = {};

    # we're figuring out 'tree' and 'subtrees' based on our contents
    # they will be cached on demand; start them off undef
    $self->{_tree} = undef;
    $self->{_subtrees} = undef;

    # stuffing extra stuff in buckets is not allowed
    Hash::Util::lock_keys(%$self);

    return $self;
}

# add a file to this bucket
# returns the name it was added as (might have been transformed)
sub add {
    my ( $self, %args ) = @_;

    defined( $args{$_} ) or confess( "$_ not given" )
      for qw/file blob/;

    # individual adds are not allowed for a lazy-loadable bucket
    LOGDIE "don't call add() on a lazy-loadable bucket!" if $self->{loadable};

    # validate name
    LOGDIE "bad file name: $args{file}" unless $args{file} =~ /^$RE_CHISEL_file_permissive\z/;

    # validate blob format
    LOGDIE "unrecognized blob: $args{blob}" unless $args{blob} =~ /^[a-z0-9]{40}\z/;

    # get directories implied by $args{file}
    my @file_splitdir = split m{/}, $args{file};
    my @file_dirs;
    for( my $file_splitdir_idx = 0 ; $file_splitdir_idx < ( @file_splitdir - 1 ) ; $file_splitdir_idx++ ) {
        push @file_dirs, join( '/', @file_splitdir[ 0 .. $file_splitdir_idx ] );
    }

    # make sure that this filename does not conflict with an existing one (i.e. tries to turn a directory into a file or vice versa)
    LOGDIE "new file $args{file} conflicts with existing file"
      if $self->{dir}{ $args{file} }    # it's already an implied directory
          or grep { $self->{manifest}{$_} } @file_dirs;    # one of our implied directories is already a file

    # looks ok. add implied directories to 'dir' cache and the actual file to 'manifest'
    TRACE "Adding $args{file} to bucket (blob=$args{blob})";

    $self->{dir}{$_} = 1 for @file_dirs;
    $self->{manifest}{ $args{file} } = {
        blob => $args{blob},
        mode => ( $args{file} =~ m{^scripts/} && $args{file} !~ m{\.asc$} ) ? '0755' : '0644',
        ( $args{mtime} ? ( mtime => $args{mtime} ) : () ),
        ( $args{md5}   ? ( md5   => $args{md5} )   : () ),
    };

    # clear $self->{_tree,_subtrees} which will make them regenerate next time someone asks for them
    undef $self->{_tree};
    undef $self->{_subtrees};

    return $args{file};
}

# wipe this bucket clean of all files
sub clear {
    my ( $self, %args ) = @_;

    # bucket state is kept in these vars
    %{$self->{manifest}} = ();
    %{$self->{dir}} = ();
    undef $self->{_tree};
    undef $self->{_subtrees};

    # for chaining
    return $self;
}

# returns our internal manifest directly (not a copy)
# meant to be a private method; external callers should use "manifest"
sub _manifest {
    my ( $self ) = @_;

    # time to load, if this bucket is loadable
    if( $self->{loadable} ) {
        # clear our manifest and dir cache
        $self->clear;

        # uninstall the loader
        my $loader = $self->{loadable};
        undef $self->{loadable};

        eval {
            # ->load should return a list of arguments to add()
            my @files_to_add = @{ $loader->() };
            $self->add( %$_ ) for @files_to_add;

            # print our name -- this has the side effect of re-entering manifest()
            # but it's okay because 'loadable' is done and gone
            DEBUG "Lazy-loaded bucket: $self";

            1;
        } or do {
            # there was a problem: restore the loader, clear the manifest and 'dir' cache, then re-die
            $self->{loadable} = $loader;
            $self->clear;
            LOGDIE "Error lazy-loading bucket:\n$@";
        };
    }

    return $self->{manifest};
}

# returns a normalized manifest of what we've written so far
# always creates a fresh copy of our internal manifest, so feel free to do anything with it.
# accepts optional argument 'skip' to completely omit certain files, useful for comparing everything but VERSION
# accepts optional argument 'fake' to add extra files with no md5s, useful for writing the actual MANIFEST
# accepts optional argument 'emit', a list of 'extra' keys that we want in the manifest (name, type, and mode are always present) [default md5]
# accepts one flag:
#   - include_dotfiles: normally dotfiles are excluded. this will include them.
# returns a hash like:
#   { "filename" => { name => "filename", type => "file", ... } }
sub manifest {
    my ( $self, %args ) = @_;

    # we'll return this
    my %manifest;

    # based on this
    my $og_manifest = $self->_manifest;

    # convert 'skip' and 'fake' for easy lookup
    my %skip = $args{skip} ? map { $_ => 1 } @{$args{skip}} : ();
    my %fake = $args{fake} ? map { $_ => 1 } @{$args{fake}} : ();

    # figure out what keys to emit (remove name/type since they will always be forced in)
    my @emit = $args{emit} ? grep { $_ ne 'name' && $_ ne 'type' } @{ $args{emit} } : qw/ md5 /;

    # 'mode' is always required, but needs to be in 'emit' since it's in $og_manifest
    push @emit, 'mode' if ! grep { $_ eq 'mode' } @emit;

    TRACE "Computing bucket manifest"
      . ( keys %skip ? " (skip = " . join( ' ', sort keys %skip ) . ')' : '' )
      . ( keys %fake ? " (fake = " . join( ' ', sort keys %fake ) . ')' : '' );

    # first put in the fake files
    $manifest{$_} = { name => $_, type => 'file', mode => '0644' }
      for keys %fake;

    # add everything else, with some exceptions except  and 'fake' (because we already did them)
    my @wanted_files = grep {
        !$fake{$_}         # ignore 'fake' (because we already did them)
          && !$skip{$_}    # ignore 'skip' (because we were told to)
          && ( $args{'include_dotfiles'} || $_ !~ m{(?:^|/)\.} )    # ignore dotfiles by default
    } keys %$og_manifest;

    foreach my $file (@wanted_files) {
        # confirm this file has all requested info
        if( my @missing_keys = grep { ! defined $og_manifest->{$file}{$_} } @emit ) {
            confess "Bucket: keys [@missing_keys] required for file [$file] were not present";
        }

        # set manifest entry
        $manifest{$file} = {
            name => $file,
            type => 'file',
            map { $_ => $og_manifest->{$file}{$_} } @emit
        };
    }

    return \%manifest;
}

# same arguments as manifest(), but returns json instead of a hash
sub manifest_json {
    my ( $self, %args ) = @_;

    # format is one single-line JSON document per file, like this (similar to Chisel::Manifest):
    #
    # {"mode":"0644","name":["MANIFEST"],"type":"file"}
    # {"mode":"0644","name":["MANIFEST.asc"],"type":"file"}
    # {"mode":"0644","name":["NODELIST"],"type":"file","md5":"bae96af5c787879730c480b10ea8f882"}
    # {"mode":"0644","name":["VERSION"],"type":"file","md5":"624b04cd088f692e2a006b655cca4a65"}
    # {"mode":"0644","name":["files/passwd/MAIN"],"type":"file","md5":"9bb7e40e4060c47124fbc4346b587237"}
    # {"mode":"0644","name":["files/sudoers/MAIN"],"type":"file","md5":"f5a182d545206384a6a5e4fc14809a4b"}
    #
    # ^ that particular file was generated with fake = MANIFEST, MANIFEST.asc

    # pass-through args to manifest()
    my $manifest = $self->manifest(%args);

    # disable pretty (so it's a single-line), enable canonical (so it's consistent)
    my $json_xs = JSON::XS->new->ascii->pretty(0)->canonical(1);

    # create the json lines
    my $json = join '',    # join them into a string
      map  { $json_xs->encode( $_ ) . "\n" }   # encode each hash as a single JSON line
      grep { $_->{name} = [ $_->{name} ] }     # good thing manifest() made something new for us
      sort { $a->{name} cmp $b->{name} }       # sort by filename to ensure consistency
      values %$manifest;

    return $json;
}

# get the tree sha for this bucket
# possibly cached, possibly regenerate it
sub tree {
    my ( $self ) = @_;

    if( !defined $self->{_tree} ) {
        # get the largest subtree, i.e. the bucket itself
        my $raw = scalar $self->subtrees;

        # this is how git computes tree shas
        my $sha = sha1_hex( "tree " . length( $raw ) . "\0" . $raw );

        # remember for later
        $self->{_tree} = $sha;
    }

    return $self->{_tree};
}

# return subtrees ordered from largest to smallest
# the first element returned is the whole-bucket tree
# these are returned in raw tree format (see internal comments)
# possibly cached, possibly regenerate it
sub subtrees {
    my ( $self ) = @_;

    if( !defined $self->{_subtrees} ) {
        my $manifest = $self->_manifest;

        # this sort should match how git does things; it treats directories as if they had a '/' on the end
        # and in manifest, since directories are not first class (only implied) they will have '/' on the end
        my @sorted_manifest_keys = sort keys %$manifest;

        # $subtree_raw{ 'files/homedir' } = raw tree format
        # the root tree (the whole bucket) will be indexed by '' (empty string)
        my %subtree_raw;

        # raw tree format is like this, sorted by filename:
        # 40000 [sp] files [nul] [sha in binary]         <-- directory
        # 100644 [sp] MANIFEST [nul] [sha in binary]     <-- file

        # the tree sha is computed with this header prepended:
        # tree [sp] [length of the raw tree] [nul]

        while( @sorted_manifest_keys ) {
            # let's look at the next file
            my $f = shift @sorted_manifest_keys;

            # split $f into path components (files/sudoers/MAIN -> [ files, sudoers, MAIN ])
            my @fparts = split m{/}, $f;

            # add $f to its immediate parent, $fparent
            do {
                my $shortname = $fparts[-1];
                my $fparent   = @fparts <= 1 ? '' : join( '/', @fparts[ 0 .. ( $#fparts - 1 ) ] );
                my $sha       = $manifest->{$f}{'blob'};
                my $mode      = $manifest->{$f}{'mode'};

                # commented for performance; this code gets executed many times
                # TRACE "Bucket: finding subtrees: adding blob [$shortname] under [$fparent] with sha [$sha] and mode [$mode]";
                $subtree_raw{$fparent} .= "10$mode $shortname\0" . pack( "H*", $sha );
            };

            # peek ahead at the next file; we might need to finalize some entries in %subtree_raw
            my $next_sorted_manifest_key = $sorted_manifest_keys[0];

            # examine directories implied by $f, deepest first (e.g. files/homedir/MAIN -> [ files/homedir, files ])
            for( my $i = $#fparts - 1 ; $i >= 0 ; $i-- ) {
                my $subtree_name = join( '/', @fparts[ 0 .. $i ] );

                # peek ahead; if we're done with the subtree named $subtree_name, add it to its parent
                if( !defined $next_sorted_manifest_key || substr( $next_sorted_manifest_key, 0, length $subtree_name ) ne $subtree_name ) {
                    my $shortname = $fparts[$i];
                    my $parent = ( $i == 0 ? '' : join( '/', @fparts[ 0 .. ( $i - 1 ) ] ) );
                    my $sha = sha1_hex( "tree " . length( $subtree_raw{$subtree_name} ) . "\0" . $subtree_raw{$subtree_name} );

                    # commented for performance; this code gets executed many times
                    # TRACE "Bucket: finding subtrees: adding tree [$shortname] under [$parent] with sha [$sha]";
                    $subtree_raw{ $parent } .= "40000 $shortname\0" . pack( "H*", $sha );
                }
            }
        }

        if( keys %subtree_raw ) {
            $self->{_subtrees} = [ map { $subtree_raw{$_} } sort { length $a <=> length $b } keys %subtree_raw ];
        } else {
            $self->{_subtrees} = [ '' ];
        }
    }

    return wantarray ? @{ $self->{_subtrees} } : $self->{_subtrees}[0];
}

1;
