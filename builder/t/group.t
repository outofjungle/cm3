#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 18;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::FakeFunc;

BEGIN{
    use_ok("Chisel::Builder::Group");
    use_ok("Chisel::Builder::Group::Host");
}

Log::Log4perl->init( 't/files/l4p.conf' );

# simple tests
do {
    my $g = Chisel::Builder::Group->new;
    isa_ok( $g, "Chisel::Builder::Group", "Chisel::Builder::Group object creation" );
    
    # Verify register fails when it's supposed to
    throws_ok { $g->register() } qr/plugin not given/, "no plugin";
    throws_ok { $g->register( plugin => $g ) } qr/Invalid plugin/, "invalid plugin";
    
    # parse
    eq_or_diff( [$g->parse("group_role/some.sweet.role")], ["group_role","some.sweet.role"], "Simple parse");
    eq_or_diff( [$g->parse('my/bad/uri')], [], "Return empty array on bad uri");
    eq_or_diff( [$g->parse('cmdb_usergroup/')], [], "Return empty array on missing minor id");
    eq_or_diff( [$g->parse('/nomajor')], [], "Return empty array on missing major id");
};

# test its ability to use a single plugin
do {
    my $g      = Chisel::Builder::Group->new();
    my $g_host = Chisel::Builder::Group::Host->new();
    ok( $g->register( plugin => $g_host ), "Register host plugin" );

    # toss a softball
    eq_or_diff(
        $g->group(
            nodes  => ['some.host.name'],
            groups => ['host/SoMe.HoST.NaMe']
        ),
        { 'some.host.name' => ['host/SoMe.HoST.NaMe'] },
        "basic node => group association"
    );

    eq_or_diff(
        $g->group(
            nodes  => [ 'some.host.NAME',      'other.host.name',       'yet-another.host.name' ],
            groups => [ 'host/SoMe.HoST.NaMe', 'host/other2.host.name', 'host/yet-another.HOST.NAME' ],
        ),
        { 'some.host.NAME' => ['host/SoMe.HoST.NaMe'], 'yet-another.host.name' => ['host/yet-another.HOST.NAME'] },
        "node => group association that requires ignoring some nodes and groups"
    );

    eq_or_diff(
        $g->group(
            nodes => [ 'some.host.NAME', 'other.host.name', 'yet-another.host.name', 'YET-ANOTHER.host.name' ],
            groups =>
              [ 'host/SoMe.HoST.NaMe', 'host/some.HOST.name', 'host/other2.host.name', 'host/yet-another.HOST.NAME' ],
        ),

        # it should take the last one due to the way deduping was implemented, although technically this isn't promised anywhere
        { 'some.host.NAME' => ['host/some.HOST.name'], 'YET-ANOTHER.host.name' => ['host/yet-another.HOST.NAME'] },
        "node => group association that requires deduping"
    );
};

# test its ability to use multiple plugins
do {
    my $g = Chisel::Builder::Group->new;
    my $g_host = Chisel::Builder::Group::Host->new;
    my $g_ffnc = ChiselTest::FakeFunc->new( "t/files/ranges.yaml" );
    $g->register( plugin => $g_host );
    $g->register( plugin => $g_ffnc );
    
    # run one of the tests from above, to make sure it still works
    eq_or_diff(
        $g->group(
            nodes  => ['some.host.name'],
            groups => ['host/SoMe.HoST.NaMe']
        ),
        { 'some.host.name' => ['host/SoMe.HoST.NaMe'] },
        "basic node => group association (2 plugins, 1 unused)"
    );
    
    # ffnc supplies "cmdb_property" and "func", let's try to use them
    # for this test we need to sort the result, since order is not guaranteed
    
    my $group_result = $g->group(
        nodes => [ 'some.host.name', 'bar2', 'barqux1' ],
        groups => [ 'func/FOO', 'func/BAR', 'func/QUX', 'cmdb_property/taga', 'host/SoMe.HoST.NaMe', 'host/bar2', ]
    );
    
    @$_ = sort @$_ for values %$group_result;
    
    eq_or_diff(
        $group_result,
        {
            'some.host.name' => [ 'host/SoMe.HoST.NaMe' ],
            'bar2'           => [ 'func/BAR', 'host/bar2' ],
            'barqux1'        => [ 'func/BAR', 'func/QUX', 'cmdb_property/taga' ]
        },
        "basic node => group association (2 plugins)"
    );
    
    # try using zero nodes
    eq_or_diff(
        $g->group(
            nodes  => [],
            groups => [ 'func/FOO', 'func/BAR', 'func/QUX', 'cmdb_property/taga', 'host/SoMe.HoST.NaMe', 'host/bar2', ]
        ),
        {},
        "basic node => group association (2 plugins, 0 nodes)"
    );
};

# see what it does when the plugin sends something silly
do {
    my $g = Chisel::Builder::Group->new;
    my $g_host = Chisel::Builder::Group::Host->new;
    my $g_ffnc = ChiselTest::FakeFunc->new( "t/files/ranges.yaml" );
    $g_ffnc->{ret} = []; # it'll send this to callbacks instead of something normal
    $g->register( plugin => $g_host );
    $g->register( plugin => $g_ffnc );
    
    # run one of the tests from above, to make sure it still works
    eq_or_diff(
        $g->group(
            nodes  => ['some.host.name'],
            groups => ['host/SoMe.HoST.NaMe']
        ),
        { 'some.host.name' => ['host/SoMe.HoST.NaMe'] },
        "basic node => group association (2 plugins, 1 unused)"
    );
    
    # let's try to use ffnc
    
    throws_ok {
        $g->group(
            nodes => [ 'some.host.name', 'bar2', 'barqux1' ],
            groups => [ 'func/FOO', 'func/BAR', 'func/QUX', 'cmdb_property/taga', 'host/SoMe.HoST.NaMe', 'host/bar2', ]
        );
    }
    qr/\QInvalid callback\E/, "group() dies when a plugin calls back with nothing";
};
