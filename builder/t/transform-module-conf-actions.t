#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 7;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN { use_ok( "Chisel::Transform" ); }

# make a basic transform, but add a module.conf
do {
    my $t = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => <<'EOT',
# '2' is a macro for 'prepend two'
# even though 'prepend' is not an allowed action, it can exist as part of a macro
motd: [ append one, 2 ]

sudoers: [ append three, prepend four ]
EOT
        module_conf => { motd => { actions => ['append'], macros => { '2' => { 'motd' => ['prepend two'] } } } },
    );

    # load the list of files
    eq_or_diff( [ sort $t->files ], [qw{ files/motd/MAIN files/sudoers/MAIN }], "DEFAULT file list is correct" );

    # load rules for motd
    eq_or_diff(
        [ $t->rules( file => "files/motd/MAIN" ) ],
        [ [ 'append', 'one' ], [ 'prepend', 'two' ] ],
        "files/motd/MAIN rules are correct",
    );

    # load rules for sudoers
    eq_or_diff(
        [ $t->rules( file => "files/sudoers/MAIN" ) ],
        [ [ 'append', 'three' ], [ 'prepend', 'four' ] ],
        "files/sudoers/MAIN rules are correct",
    );
};

do {
    # these three should be a bad transform due to violation of 'actions'
    my $t2 = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => <<'EOT',
motd: [ append one, prepend two ]
sudoers: [ append three, prepend four ]
EOT
        module_conf => { motd => { actions => ['append'], }, },
    );

    my $t3 = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => <<'EOT',
motd/x: [ append one, prepend two ]
sudoers: [ append three, prepend four ]
EOT
        module_conf => { motd => { actions => ['append'], }, },
    );

    my $t4 = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => <<'EOT',
motd/x: [ append one, prepend two ]
sudoers: [ append three, prepend four ]
EOT
        module_conf => { motd => { actions => [], }, },
    );

    # try doing something with these transforms, they should be DOA
    throws_ok { $t2->files } qr!'prepend' not supported in 'motd'!,   "actions violation causes tranform to die";
    throws_ok { $t3->files } qr!'prepend' not supported in 'motd/x'!, "actions violation causes tranform to die";
    throws_ok { $t4->files } qr!'append' not supported in 'motd/x'!,  "actions violation causes tranform to die";
};
