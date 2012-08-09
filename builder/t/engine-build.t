#!/usr/bin/perl

# engine-build.t -- the most high-level test of the builder, tests a build end-to-end

use warnings;
use strict;
use Test::More skip_all => "this high-level test should be replaced by Overmind tests";
use Test::Differences;
use Test::ChiselBuilder qw/:all/;
use YAML::XS ();
use JSON::XS ();
use Digest::MD5 qw/ md5_hex /;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

# all of these tests use the same git repository in "$tmp/git"
my $tmp = tcb_tmp;
my $engine = tcb_engine;

# this is what nodes should be linked to
# (the names here are keys from "expected.yaml")
# XXX 'undef' means the node should exist but we know expected.yaml doesn't have a key for it :(
my %node_expected = (
    # DEFAULT func/FOO DEFAULT_TAIL
    'foo1' => undef,
    'foo2' => undef,
    'foo3' => undef,
    
    # DEFAULT func/BAR DEFAULT_TAIL
    'bar2' => undef,
    'bar3' => undef,

    # DEFAULT func/BAR host/bar1 DEFAULT_TAIL
    'bar1' => undef,

    # DEFAULT func/QUX DEFAULT_TAIL
    'qux1' => undef,
    'qux2' => undef,
    'qux3' => undef,

    # DEFAULT func/FOO func/BAR DEFAULT_TAIL
    'foobar1' => undef,
    'foobar2' => undef,
    
    # DEFAULT func/FOO func/QUX DEFAULT_TAIL
    'fooqux1' => 'fooqux',

    # DEFAULT func/BAR func/QUX DEFAULT_TAIL
    'barqux1' => 'barqux',
    'barqux2' => 'barqux',

    # DEFAULT func/FOO func/BAR func/QUX DEFAULT_TAIL
    'foobarqux1' => undef,
);

do {
    my $r = do_build(
        range         => [ keys %node_expected ],
        checkout_args => {
            rawdir       => "t/files/configs.1/raw",
            transformdir => "t/files/configs.1/transforms",
            tagdir       => "t/files/configs.1/tags.0",
            scriptdir    => "t/files/configs.1/modules",
        },
        walrus_args    => { groupobj => new_groupobj, require_group => undef },
        generator_args => {
            version       => 12345,
            sanity_socket => undef,    # so we don't try to establish a socket
            repo          => '',       # so we don't try to run "svn info"
        },
    );
    
    ok( $r, "build() ran successfully" );
    post_build_check( \%node_expected );
};

# ok let's remove some of these nodes and make sure the right thing happens
delete $node_expected{$_} for qw/ barqux1 barqux2 foobarqux1 /;

do {
    my $r = do_build(
        range          => [ keys %node_expected ],
        checkout_args => {
            rawdir       => "t/files/configs.1/raw",
            transformdir => "t/files/configs.1/transforms",
            tagdir       => "t/files/configs.1/tags.0",
            scriptdir    => "t/files/configs.1/modules",
        },
        walrus_args    => { groupobj => new_groupobj, require_group => undef },
        generator_args => {
            version       => 12346,
            sanity_socket => undef,    # so we don't try to establish a socket
            repo          => '',       # so we don't try to run "svn info"
        },
    );

    ok( $r, "build() ran successfully the second time" );
    post_build_check( \%node_expected );
};

# alright let's switch to broken configs, we should see a partial failure

do {
    my $r = do_build(
        range          => [ keys %node_expected ],
        checkout_args => {
            rawdir       => "t/files/configs.1/raw",
            transformdir => "t/files/configs.1/transforms.partial",
            tagdir       => "t/files/configs.1/tags.0",
            scriptdir    => "t/files/configs.1/modules",
        },
        walrus_args    => { groupobj => new_groupobj, require_group => undef },
        generator_args => {
            version       => 12347,
            sanity_socket => undef,    # so we don't try to establish a socket
            repo          => '',       # so we don't try to run "svn info"
        },
    );

    ok( $r, "build() ran successfully with some broken configs" );

    # important to note that this will check 'fooqux1' -> 'fooqux' still
    # (it should be, since fooqux1 should have partially failed)
    post_build_check( \%node_expected );
    
    my $ws = Chisel::Workspace->new( dir => "$tmp/ws" );

    # fooqux1 should not have been updated since even the first run, since it should have failed
    my $ver_fooqux1 = $ws->cat_blob( $ws->nodemap->{'fooqux1'}->manifest( emit => ['blob'] )->{'VERSION'}{'blob'} );
    my $motd_fooqux1 = $ws->cat_blob( $ws->nodemap->{'fooqux1'}->manifest( emit => ['blob'] )->{'files/motd/MAIN'}{'blob'} );
    like( $motd_fooqux1, qr/hello world/, "fooqux1 motd still contains 'hello world'" );
    is( $ver_fooqux1, "12345\n", "fooqux1 VERSION does not increment in case of partial failure" );
    
    # but foo1 should have been updated
    my $ver_foo1 = $ws->cat_blob( $ws->nodemap->{'foo1'}->manifest( emit => ['blob'] )->{'VERSION'}{'blob'} );
    my $motd_foo1 = $ws->cat_blob( $ws->nodemap->{'foo1'}->manifest( emit => ['blob'] )->{'files/motd/MAIN'}{'blob'} );
    like( $motd_foo1, qr/transforms\.partial/, "foo1 motd mentions 'transforms.partial'" );
    is( $ver_foo1, "12347\n" );
};

# run it again make sure nothing changes

do {
    my $r = do_build(
        range          => [ keys %node_expected ],
        checkout_args => {
            rawdir       => "t/files/configs.1/raw",
            transformdir => "t/files/configs.1/transforms.partial",
            tagdir       => "t/files/configs.1/tags.0",
            scriptdir    => "t/files/configs.1/modules",
        },
        walrus_args    => { groupobj => new_groupobj, require_group => undef },
        generator_args => {
            version       => 12348,
            sanity_socket => undef,    # so we don't try to establish a socket
            repo          => '',       # so we don't try to run "svn info"
        },
    );

    ok( $r, "build() ran successfully with some broken configs, the second time" );

    # important to note that this will check 'fooqux1' -> 'fooqux' still
    # (it should be, since fooqux1 should have partially failed)
    post_build_check( \%node_expected );
    
    my $ws = Chisel::Workspace->new( dir => "$tmp/ws" );

    # fooqux1 should not have been updated since even the first run, since it should have failed
    my $ver_fooqux1 = $ws->cat_blob( $ws->nodemap->{'fooqux1'}->manifest( emit => ['blob'] )->{'VERSION'}{'blob'} );
    my $motd_fooqux1 = $ws->cat_blob( $ws->nodemap->{'fooqux1'}->manifest( emit => ['blob'] )->{'files/motd/MAIN'}{'blob'} );
    like( $motd_fooqux1, qr/hello world/, "fooqux1 motd still contains 'hello world'" );
    is( $ver_fooqux1, "12345\n", "fooqux1 VERSION does not increment in case of partial failure" );
    
    # this time foo1 should not be updated, since nothing changed
    my $ver_foo1 = $ws->cat_blob( $ws->nodemap->{'foo1'}->manifest( emit => ['blob'] )->{'VERSION'}{'blob'} );
    my $motd_foo1 = $ws->cat_blob( $ws->nodemap->{'foo1'}->manifest( emit => ['blob'] )->{'files/motd/MAIN'}{'blob'} );
    like( $motd_foo1, qr/transforms\.partial/, "foo1 motd mentions 'transforms.partial'" );
    is( $ver_foo1, "12347\n" );
};

# fix the configs, make sure it goes back to normal

do {
    my $r = do_build(
        range          => [ keys %node_expected ],
        checkout_args => {
            rawdir       => "t/files/configs.1/raw",
            transformdir => "t/files/configs.1/transforms",
            tagdir       => "t/files/configs.1/tags.0",
            scriptdir    => "t/files/configs.1/modules",
        },
        walrus_args    => { groupobj => new_groupobj, require_group => undef },
        generator_args => {
            version       => 12349,
            sanity_socket => undef,    # so we don't try to establish a socket
            repo          => '',       # so we don't try to run "svn info"
        },
    );

    ok( $r, "build() ran successfully after the broken configs were fixed" );
    post_build_check( \%node_expected );
    
    my $ws = Chisel::Workspace->new( dir => "$tmp/ws" );

    # fooqux1 should not have been updated since even the first run, since even though it's not failed anymore, there's no change
    my $ver_fooqux1 = $ws->cat_blob( $ws->nodemap->{'fooqux1'}->manifest( emit => ['blob'] )->{'VERSION'}{'blob'} );
    my $motd_fooqux1 = $ws->cat_blob( $ws->nodemap->{'fooqux1'}->manifest( emit => ['blob'] )->{'files/motd/MAIN'}{'blob'} );
    like( $motd_fooqux1, qr/hello world/, "fooqux1 motd still contains 'hello world'" );
    is( $ver_fooqux1, "12345\n", "fooqux1 VERSION does not increment in case of partial failure" );
    
    # but foo1 should go back to normal -- note the switch to 'unlike'
    my $ver_foo1 = $ws->cat_blob( $ws->nodemap->{'foo1'}->manifest( emit => ['blob'] )->{'VERSION'}{'blob'} );
    my $motd_foo1 = $ws->cat_blob( $ws->nodemap->{'foo1'}->manifest( emit => ['blob'] )->{'files/motd/MAIN'}{'blob'} );
    unlike( $motd_foo1, qr/transforms\.partial/, "foo1 motd no longer mentions 'transforms.partial'" );
    is( $ver_foo1, "12349\n" );
};

sub do_build { # simplest code to do a single build
    my %args = @_;

    my @hostnames = @{$args{'range'}};
    my $checkout  = $engine->new_checkout( %{$args{'checkout_args'}} );

    my $walrus = $engine->new_walrus( transforms => [ $checkout->transforms ], tags => [ $checkout->tags ], %{$args{'walrus_args'}} );
    $walrus->add_host( host => $_ ) for @hostnames;

    my $generator = $engine->new_generator( raw => [$checkout->raw], %{$args{'generator_args'}} );
    $generator->add_host( host => $_, transforms => [$walrus->host_transforms( host => $_ )] ) for $walrus->range;
    $generator->generate;
}

sub post_build_check { # check some basic bucket stuff
    my ( $nodes, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    
    # check:
    # - each node exists, and no other nodes exist
    # - node files generally make sense
    # - node files match expected.yaml (%expected, it's a global)
    
    $message ||= "generic post_build_check";
    
    subtest $message => sub {
        # there's going to be 1 global tests plus 8 tests per node
        plan tests => 1 + 8 * scalar keys %$nodes;
        
        my $ws = Chisel::Workspace->new( dir => "$tmp/ws" );
        my $ws_nodemap = $ws->nodemap;
        
        # first make sure the names of the nodes are the same, at least
        eq_or_diff( [ sort keys %$ws_nodemap ], [ sort keys %$nodes ], "nodemap matches expectations" );
        
        # do various more demanding checks
        foreach my $node (keys %$nodes) {
            # grab the file list from this node's bucket
            my $bucket = $ws_nodemap->{$node};
            my $manifest = $bucket->manifest( emit => ['blob'] );
            
            # check for special files MANIFEST, VERSION, and NODELIST
            ok( exists $manifest->{'MANIFEST'}, "node $node has MANIFEST" );
            ok( exists $manifest->{'VERSION'},  "node $node has VERSION" );
            ok( exists $manifest->{'NODELIST'}, "node $node has NODELIST" );
            
            # check contents of NODELIST and VERSION
            ok( $ws->cat_blob( $manifest->{'NODELIST'}{'blob'} ) =~ /^\Q$node\E$/m,   "node $node is in its own NODELIST" );
            like( $ws->cat_blob( $manifest->{'VERSION'}{'blob'} ),  qr/^\d+$/,        "node $node has numeric VERSION" );
            
            # parse its MANIFEST so we can check stuff
            my $json_xs = JSON::XS->new->ascii;
            my $manifest_txt = $ws->cat_blob( $manifest->{'MANIFEST'}{'blob'} );
            my @manifest_txt_lines
                = sort { $a->{'name'}[0] cmp $b->{'name'}[0] } # alphabetical sort by filename will be useful for the other tests
                  map  { $json_xs->decode($_) }                # each line of the file is a JSON document
                  split "\n", $manifest_txt;
            
            # check MANIFEST file names to ensure they match the actual files
            eq_or_diff(
                [ map { $_->{'name'}[0] } @manifest_txt_lines ], # file names from MANIFEST file
                [ sort keys %$manifest ], # file names from $ws
                "MANIFEST file names are correct"
            );
            
            # check MANIFEST file md5s to ensure they match the actual files
            eq_or_diff(
                [   map { $_->{'md5'} } # extract md5 from MANIFEST
                    grep { $_->{'name'}[0] !~ /^MANIFEST(\.asc|)$/ } # we need to skip MANIFEST, MANIFEST.asc since they have no md5
                    @manifest_txt_lines 
                ],    
                [   map  { md5_hex( $ws->cat_blob( $manifest->{$_}{'blob'} ) ) } # get md5 by hashing the actual contents
                    grep { !/^MANIFEST(\.asc|)$/ } # again, skip MANIFEST and MANIFEST.asc
                    sort keys %$manifest
                ],
                "MANIFEST file md5s are correct"
            );
            
            # optional (XXX probably should not be optional) -- check against a particular key in expected.yaml
            if( defined $nodes->{$node} ) {
                my %expected = %{ YAML::XS::LoadFile( 't/files/expected.yaml' ) };

                # $exp is going to be something similar to $manifest, except:
                # - $exp has got md5s added
                # - $exp only includes transform-generated files (not the top-level special ones)
                
                my $exp = $expected{$nodes->{$node}};
                
                # minimal fixup of $exp to match $manifest -- don't fixup so much that the test is useless
                delete $_->{'md5'} for values %$exp;
                $exp->{$_} = $manifest->{$_} for qw/ MANIFEST MANIFEST.asc NODELIST VERSION REPO /;
                
                eq_or_diff( $manifest, $exp, "node $node matches expected bucket" );
            } else {
                # dummy test to keep the count up
                note( "node $node has no expected bucket" );
                pass();
            }
        }
    };
}
