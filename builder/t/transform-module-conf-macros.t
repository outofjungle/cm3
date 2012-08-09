#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 18;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Transform"); }

# make a basic transform, but add a module.conf
my %module_conf = (
    motd => {
        macros => {
            'doit' => {
                'files/motd/x' => ['append rofl2'],
                'files/motd/y' => ['include rofl3']
            },
        }
    },
    motd2 => {
        macros => {
            'doit'      => { 'motd/x' => ['nop'] },
            'doitagain' => { 'motd/x' => ['unlink'] }
        }
    },
    motd3 => {
        default_file => [ 'x', 'y' ],
        macros => {
            '2' => {
                'files/motd3/x' => ['append two'],
                'files/motd3/y' => ['append two'],
            },
        }
    },
);

# ensure two transforms parse the same way
# at one point in development there was a bug where module_conf would be mangled by a transform;
# this checks for something similar to that bug.

my $t1 = Chisel::Transform->new(
    name => 'DEFAULT',
    yaml => <<'EOT',
# module motd
motd:          [ doit ]
files/motd/x:  [ append rofl ]

# module motd2
motd2:         [ doit, nop, doitagain ]

# module motd3
motd3:         [ append one, 2 ]
motd3/x:       [ append three ]
files/motd3/x: [ append four ]

# module passwd
passwd:        [ truncate ]
EOT
    module_conf => \%module_conf,
);

my $t2 = Chisel::Transform->new(
    name        => 'DEFAULT',
    yaml        => $t1->yaml,
    module_conf => \%module_conf,
);

foreach my $t ( $t1, $t2 ) {
    # load the list of files
    eq_or_diff(
        [ sort $t->files ],
        [ qw{ files/motd/x files/motd/y files/motd2/MAIN files/motd3/x files/motd3/y files/passwd/MAIN } ],
        "DEFAULT file list is correct"
    );

    # check rules for these files
    eq_or_diff( [ $t->rules( file => "files/motd/x" ) ], [ [ 'append', 'rofl2' ], ['nop'], ['unlink'], [ 'append', 'rofl' ] ] );
    eq_or_diff( [ $t->rules( file => "files/motd/y" ) ], [ [ 'include', 'rofl3' ] ] );
    eq_or_diff( [ $t->rules( file => "files/motd2/MAIN" ) ],  [ ['nop'] ] );
    eq_or_diff( [ $t->rules( file => "files/motd3/x" ) ],  [ ['append', 'one'], ['append', 'two'], ['append', 'three'], ['append', 'four'] ] );
    eq_or_diff( [ $t->rules( file => "files/motd3/y" ) ],  [ ['append', 'one'], ['append', 'two'] ] );
    eq_or_diff( [ $t->rules( file => "files/passwd/MAIN" ) ], [ ['truncate'] ] );

    # check raw_needed
    eq_or_diff( [ $t->raw_needed ], ['rofl3'] );
}

# this one should be bad; macros only work on bare names like "motd"
my $t3 = Chisel::Transform->new(
    name => 'DEFAULT',
    yaml => <<'EOT',
motd/z: [ doit ]
EOT
    module_conf => \%module_conf,
);

throws_ok { $t3->files } qr/'doit' is not a valid action/;
