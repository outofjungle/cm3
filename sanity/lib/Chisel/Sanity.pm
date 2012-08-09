######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::Sanity;
use warnings;
use strict;
use Chisel::Integrity;
use Log::Log4perl qw/:easy/;
use JSON::XS ();
use Hash::Util ();
use Digest::MD5 qw/md5_hex/;
use Carp;

sub new {
    my ( $class, %rest ) = @_;

    my $defaults = {
        # these should be provided
        scriptdir  => '',
        tmpdir     => '',
        gnupghome  => '',

        # these can but probably shouldn't be
        modules    => undef,    # list of modules
        checkcache => {},       # $checkcache{ "passwd script;;fileA;;md5A;;fileB;;md5B" (sorted by filename) }
                                #   = 1 (good), 0 (bad), undef (unknown)
        errorcache => {},       # $errorcache{ "passwd script;;fileA;;md5A;;fileB;;md5B" (sorted by filename) }
                                #   = error iff there was one
    };

    my $self = { %$defaults, %rest };

    if( keys %$self > keys %$defaults ) {
        confess "Too many parameters: " . join ", ", keys %rest;
    }

    # create an Integrity object
    $self->{integrity_obj} = Chisel::Integrity->new( gnupghome => $self->{gnupghome} );

    bless $self, $class;
    Hash::Util::lock_keys(%$self);

    DEBUG "Sanity checker scriptdir=$self->{scriptdir} gnupghome=$self->{gnupghome}";

    return $self;
}

sub integrity { shift->{integrity_obj} };

# notify the sanity checker that a blob will be needed at some point in the future
# this is triggered by the 'bl' command from the builder
sub add_blob {
    my ( $self, %args ) = @_;
    defined( $args{$_} )
      or confess( "$_ not given" ) for qw/contents/;

    # write this blob out to tmpdir/bl/7a/6caeb7178fc10cf4a4166c3dceb5b7 (if its md5 is 7a6caeb7178fc10cf4a4166c3dceb5b7)

    my $md5 = md5_hex( $args{contents} );
    my ( $p1, $p2 ) = ( $md5 =~ /^([a-f0-9]{2})([a-f0-9]{30})$/ );

    if( $p1 && $p2 ) {
        mkdir "$self->{tmpdir}/bl"     if !-d "$self->{tmpdir}/bl";
        mkdir "$self->{tmpdir}/bl/$p1" if !-d "$self->{tmpdir}/bl/$p1";
        open my $fd, ">", "$self->{tmpdir}/bl/$p1/$p2"
          or LOGDIE "open $self->{tmpdir}/bl/$p1/$p2: $!";
        print $fd $args{contents};
        close $fd;
    }
}

# request checking and a signature for a particular bucket
# this is triggered by the 'ck' command from the builder
sub check_bucket {
    my ( $self, %args ) = @_;
    defined( $args{$_} )
      or confess( "$_ not given" ) for qw/manifest/;

    my $bucket = md5_hex( $args{'manifest'} );

    DEBUG "Performing sanity check on bucket=$bucket";

    # retrieve the file list for this bucket
    my $m = $args{'manifest'};
    my $json_xs = JSON::XS->new->ascii;
    my @manifest = map { $json_xs->decode($_) } split "\n", $m;

    # build a list of files and scripts for each module
    my %scripts;
    my %files;

    foreach my $file (@manifest) {
        my ($name, @rest) = @{$file->{name}};
        my $md5 = $file->{md5};

        # validate format of this manifest entry
        LOGDIE "missing 'name' in manifest for $bucket"                 if ! $name;
        LOGDIE "extra names in manifest for $bucket: $name @rest"       if @rest;
        LOGDIE "missing 'md5' in manifest for $bucket (file = $name)"   if ! $md5 && $name ne 'MANIFEST' && $name ne 'MANIFEST.asc';
        LOGDIE "extra 'md5' in manifest for $bucket (file = $name)"     if $md5 && ( $name eq 'MANIFEST' || $name eq 'MANIFEST.asc' );
        LOGDIE "bad 'md5' in manifest for $bucket (file = $name)"       if $md5 && $md5 !~ /^[a-z0-9]{32}$/;
        LOGDIE "type != 'file' in manifest for $bucket (file = $name)"  if $file->{type} ne 'file';
        LOGDIE "missing 'mode' in manifest for $bucket (file = $name)"  if ! $file->{mode};
        LOGDIE "too many fields in manifest for $bucket (file = $name)" if grep { $_ ne 'name' && $_ ne 'type' && $_ ne 'mode' && $_ ne 'md5' } keys %$file;

        # validate name and mode
        my $ok_filename_re = qr/[a-zA-Z][a-zA-Z0-9\.\-\_]*/;

        if( $name =~ /^(MANIFEST|MANIFEST\.asc|NODELIST|VERSION|REPO)$/ ) {
            # allowed top-level name
            LOGDIE "name = $name should be mode 0644, but it's $file->{mode}" if $file->{mode} ne '0644';
        } elsif( $name =~ m{^files/($ok_filename_re)/($ok_filename_re)$} ) {
            # legit-looking file name
            LOGDIE "name = $name should be mode 0644, but it's $file->{mode}" if $file->{mode} ne '0644';
            $files{$1}{$2} = $md5;
        } elsif( $name =~ m{^scripts/($ok_filename_re)\.asc$} ) {
            # legit-looking script signature
            LOGDIE "name = $name should be mode 0644, but it's $file->{mode}" if $file->{mode} ne '0644';
        } elsif( $name =~ m{^scripts/($ok_filename_re)$} ) {
            # legit-looking script name
            LOGDIE "name = $name should be mode 0755, but it's $file->{mode}" if $file->{mode} ne '0755';
            $scripts{$1} = $md5;
        } else {
            LOGDIE "name = $name does not look like a legitimate file name (bucket = $bucket)";
        }
    }

    # amazing, the manifest validated

    # check scripts
    foreach my $script (keys %scripts) {
        # sanity-check is required
        my $check = "$self->{scriptdir}/$script/sanity-check";
        LOGDIE "missing sanity-check for module $script" unless -x $check;

        $self->check_files(
            name   => "$script script",
            bucket => $bucket,
            check  => "$check -S $self->{tmpdir}/ck/$script",
            blobs => { $script => $scripts{$script} },
        );
    }

    foreach my $script (keys %files) {
        # sanity-check is required
        my $check = "$self->{scriptdir}/$script/sanity-check";
        LOGDIE "missing sanity-check for module $script" unless -x $check;

        $self->check_files(
            name   => "$script files",
            bucket => $bucket,
            check  => "$check -F $self->{tmpdir}/ck",
            blobs  => { %{$files{$script}} },
        );
    }

    # no checks failed, sign stuff
    my $integrity = $self->integrity;

    # success
    DEBUG "$bucket: signing manifest for chiselsanity";
    return $self->{gnupghome}
        ? $integrity->sign( contents => $m,, key => "chiselsanity" )
        : '';
}

# helper function used by check_bucket
#
# handles the mechanics of actually checking a group of files, including
# calling link_blobs, running "sanity-check", and caching the result
sub check_files {
    my ( $self, %args ) = @_;
    defined( $args{$_} )
      or confess( "$_ not given" ) for qw/name check blobs bucket/;

    # unique cache key for these files
    my $cachekey = join ';;', $args{name}, map { "$_;;$args{blobs}{$_}" } sort keys %{$args{blobs}};

    if( defined( my $cache = $self->{checkcache}{$cachekey} ) ) {
        # this particular cachekey has already been checked
        # true value means OK, false value means not OK

        if( $cache && ! exists $self->{errorcache}{$cachekey} ) {
            TRACE "$args{bucket}: PASS $args{name} (also SKIPPED, already checked in bucket $cache)";
        } else {
            LOGDIE "$args{bucket}: FAILED $args{name} (also SKIPPED) " . $self->{errorcache}{$cachekey};
        }
    } else {
        # we need to actually do the check
        $self->link_blobs( %{$args{blobs}} );

        # localize $? because our test suite runs this code inside a Test::Builder subtest.
        # They have an issue where they interpret nonzero $? as a hint that they should fail
        # themselves (I guess because it's in code that regular tests execute inside END, where
        # $? will be set to their real exit code)

        local $?;

        my $r = qx[$args{check} 2>&1];
        if( $? == 0 ) { # success
            $self->{checkcache}{$cachekey} = $args{bucket};
            TRACE  "$args{bucket}: PASS $args{name}";
        } else { # failure
            $self->{checkcache}{$cachekey} = 0;
            $self->{errorcache}{$cachekey} = "(code = " . ($?>>8) . ")\n$r";
            LOGDIE "$args{bucket}: FAILED $args{name} " . $self->{errorcache}{$cachekey};
        }
    }
}

# helper function used by check_files
# handles placing blobs into a temporary directory so shell-outs to "sanity-check" can see them
sub link_blobs {
    my ( $self, %name_md5 ) = @_;

    # ensure tmpdir/ck exists and is empty
    mkdir "$self->{tmpdir}/ck" if !-d "$self->{tmpdir}/ck";
    unlink glob "$self->{tmpdir}/ck/*";

    # make sure it got emptied out
    LOGDIE "could not empty out temp directory: $!\n" if glob "$self->{tmpdir}/ck/*";

    # link in the requested blobs
    foreach my $name (keys %name_md5) {
        my $md5 = $name_md5{$name};
        my $target = "$self->{tmpdir}/ck/$name";

        # pull it out of tmpdir/bl
        my ( $p1, $p2 ) = ( $md5 =~ /^([a-f0-9]{2})([a-f0-9]{30})$/ );
        if( $p1 && $p2 ) {
            link "$self->{tmpdir}/bl/$p1/$p2" => $target
              or LOGDIE "link $self->{tmpdir}/bl/$p1/$p2 => $target: $!";
        } else {
            LOGDIE "not an md5: $md5";
        }
    }

    1;
}

1;
