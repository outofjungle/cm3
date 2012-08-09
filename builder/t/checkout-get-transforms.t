#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 1;
use Test::Differences;
use ChiselTest::Engine;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

my $engine = ChiselTest::Engine->new;
my $checkout = $engine->new_checkout;

# make sure that $checkout->{transforms} contains three transforms (keyed by group) in form {group}->{filename}->[transform]
my %exp_xforms = (
    'DEFAULT@05c23445ef27b1dfe3721899b24e91d7df6a1fdc' => {
        'files/motd/MAIN'      => [ ['append', 'hello world'] ],
        'files/sudoers/MAIN'   => [ ['append', 'bob'] ],
        'files/passwd/MAIN'    => [ ['append', 'MAIN'], ['append', 'MAIN'] ],
        'files/passwd/freebsd' => [ ['add', 'bob'], ['add', 'carol'] ],
        'files/passwd/linux'   => [ ['add', 'bob'], ['add', 'carol'] ],
        'files/passwd/shadow'  => [ ['add', 'bob'], ['add', 'carol'] ],
        'scripts/passwd'       => [ ['use', 'passwd.1'] ],
    },
    'DEFAULT_TAIL@1d8ff62ef10931b76611097844a52f9d0ea936b1' => {
        'files/sudoers/MAIN'   => [ ['dedupe'] ],
        'files/passwd/freebsd' => [ ['sortuid'], ['dedupe'], ['replacere', '^([^:]+:[^:]+:[^:]+:[^:]+):(.+)$ $1::0:0:$2'] ],
        'files/passwd/linux'   => [ ['sortuid'], ['dedupe'], ['replacere', '^([^:]+):[^:]+: $1:x:'] ],
        'files/passwd/shadow'  => [ ['sortuid'], ['dedupe'], ['replacere', '^([^:]+:[^:]+):.+$', '$1:13846:0:99999:7:::'] ],
    },
    'func/>\'a(b) & c"@3236707a1553df01d28efbc3c55af82c45fa736c' => {
        'files/motd/MAIN'      => [ ['append', 'blah blah'] ],
    },
    'func/BADBAD@ef6726e24e3d7791bca27386640cf9b7fe3ed522' => {
        'files/motd/MAIN'      => [ ['append', 'qux motd'], ['include', 'nonexistent'] ],
    },
    'func/BAR@4f097857906bbe2c2b8a9f5bc19f01506b1ac906' => {
        'files/motd/MAIN'      => [ ['append', 'Hello BAR' ] ],
        'files/sudoers/MAIN'   => [ ['append', 'bob'], ['append', 'carol'] ],
        'files/passwd/freebsd' => [ ['remove', 'bob'] ],
        'files/passwd/linux'   => [ ['remove', 'bob'] ],
        'files/passwd/shadow'  => [ ['remove', 'bob'] ],
    },
    'func/BINARY@055fc395cd8d90d020f004c3fff5146335d9177b' => {
        'files/fake.png/MAIN' => [ ['use', 'fake.png'] ],
        'files/rawtest/MAIN'   => [ ['use', 'rawtest'] ],
    },
    'func/FOO@cff4723c1e4545a2cec9220c64e30a639ccc6dba' => {
        'files/motd/MAIN'      => [ ['append', 'Hello FOO'] ],
        'files/sudoers/MAIN'   => [ ['unlink'] ],
    },
    'func/INVALID@ee139c40f14fe0f73fa6ec416b951f7eeea01ccc' => undef,
    'func/MODULE_BUNDLE@30cd2437654c58ec1aa818bb9d57031091579b6f' => {
        'scripts/passwd'       => [ ['use', 'passwd.1'] ],
        'files/passwd/freebsd' => [ ['use', 'passwd.bundle/base'] ],
        'files/passwd/linux'   => [ ['use', 'passwd.bundle/base'] ],
        'files/passwd/shadow'  => [ ['use', 'passwd.bundle/base'] ],
    },
    'func/UNICODE@e2728973f1889e71f7f4e393089fb2ffc8e4f1f7' => {
        'files/motd/MAIN' => [
            [ 'replace', 'hello world', "\x{4f60}\x{597d}\x{4e16}\x{754c}" ],
            [
                'replace',
                "\x{4f60}\x{597d}\x{4e16}\x{754c}",
                "\x{5e9}\x{5dc}\x{5d5}\x{5dd} \x{5d4}\x{5e2}\x{5d5}\x{5dc}\x{5dd}"
            ],
            [ 'include', 'unicode' ],
            [ 'replacere', "\x{2639}", ':)' ],
            [ 'replace',   ':(',       "\x{263b}" ],
            [ 'replacere', 'T_T',      "\x{263a}" ]
        ],
        'files/homedir/MAIN' => [ [ 'append', "johndoe:\n    - \x{2665}" ], [ 'addkey', "johndoe \x{2766}" ], ],

    },
    'func/QUX@03e9a760575a2eaaba907d3b4321871b1190a7d2' => {
        'files/motd/MAIN'      => [ ['replace', 'BAR 1234X'], ['replacere', '\d{4}', 'QU'] ],
        'files/quxfile/MAIN'   => [ ['nop'] ],
    },
    'host/bar1@3fdc9b10779e72c81c0d7ca8d4acd0c52b981a7a' => {
        'files/motd/MAIN'      => [ ['append', 'I am bar1'] ],
    },
    'host/not.a.host@4c139c7efb7a39caf5aa35acd3175130bdfa12c4' => {
        'files/motd/MAIN'      => [ ['append', 'this is not actually a host'] ],
    },
);

# test transforms()
my @trs = $checkout->transforms;
my %got_xforms;
foreach my $tr ( @trs ) {
    if( $tr->is_good ) {
        foreach my $file ( $tr->files ) {
            $got_xforms{$tr}{$file} = [ $tr->rules( file => $file, compile => 0 ) ];
        }
    } else {
        $got_xforms{$tr} = undef;
    }
}

eq_or_diff( \%got_xforms, \%exp_xforms, "transforms" );
