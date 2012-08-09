package Test::Workspace;

use strict;
use warnings;
use Carp;
use Test::More;
use File::Temp qw/ tempdir /;
use Chisel::Bucket;
use Chisel::Workspace;

use Exporter qw/import/;
our @EXPORT_OK = qw/ wsinit blob nodemap1 nodemap2 /;
our %EXPORT_TAGS = ( "all" => [@EXPORT_OK], );

sub wsinit { # create a new working directory
    # it's gonna be in a temp directory right here
    my $tmp = tempdir( CLEANUP => 0, DIR => "." );
    return $tmp;
}

# we have a few standard items we play with:
#  - some blobs
#  - two nodemaps that use them

sub blob {
    my $txt = shift;

    my %blobs = (
        "hello world\n" => '3b18e512dba79e4c8300dd08aeb37f8e728b8dad',
        "foo bar baz\n" => '1aeaedbf4ee8dccec5bc2b1f1168efef19378ffd',
        ""              => 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391',
    );

    if( !defined $txt ) {
        return keys %blobs;
    } if( exists $blobs{$txt} ) {
        return $blobs{$txt};
    } else {
        croak "bad test";
    }
}

sub nodemap1 {
    my $bucket1 = Chisel::Bucket->new;
    $bucket1->add( file => 'files/one/two', blob => blob("hello world\n") );
    $bucket1->add( file => 'files/three',   blob => blob("foo bar baz\n") );

    my $bucket2 = Chisel::Bucket->new;
    $bucket2->add( file => 'files/one/two', blob => blob("foo bar baz\n") );
    $bucket2->add( file => 'files/three',   blob => blob("") );
    $bucket2->add( file => '4" four',       blob => blob("hello world\n") );

    my %nodemap = (
        'ha' => $bucket1,
        'hb' => $bucket1,
        'hc' => $bucket2,
        'hd' => $bucket2,
    );

    # make them generate their subtrees
    $bucket1->tree;
    $bucket2->tree;

    return \%nodemap;
}

sub nodemap2 {
    my $bucket1 = Chisel::Bucket->new;
    $bucket1->add( file => 'files/one/two', blob => blob("hello world\n") );
    $bucket1->add( file => 'files/three',   blob => blob("foo bar baz\n") );

    my $bucket2 = Chisel::Bucket->new;
    $bucket2->add( file => 'files/one/two', blob => blob("foo bar baz\n") );
    $bucket2->add( file => 'files/three',   blob => blob("") );
    $bucket2->add( file => '4" four',       blob => blob("hello world\n") );

    my %nodemap = (
        'ha' => $bucket1, # same
        'hb' => $bucket2, # switched from 1 -> 2
        'hx' => $bucket2, # new node
    );

    # make them generate their subtrees
    $bucket1->tree;
    $bucket2->tree;

    return \%nodemap;
}
