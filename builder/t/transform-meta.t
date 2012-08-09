#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 21;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

BEGIN{ use_ok("Chisel::Transform"); }

# make a transform with good rules and good metadata
do {
    my $t = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => <<'EOT',
motd:
    - append rofl
---
follows:
    - xxx
    - yyy
EOT
    );
    
    is( "$t", 'DEFAULT@30a6bb3d92a3432f251331b0fee194ba24c60bc3', "stringification ok" );
    ok( ! $t->is_loaded, "DEFAULT starts unloaded" );
    
    # check metadata
    eq_or_diff(
        [ $t->meta( key => 'follows' ) ],
        [ 'xxx', 'yyy' ],
        "metadata parsing in a transform with metadata",
    );
    
    # check rules
    eq_or_diff(
        [ $t->rules( file => 'files/motd/MAIN' ) ],
        [ [ 'append', 'rofl' ] ],
        "rules parsing in a transform with metadata",
    );
};

# try one with no rules section
do {
    my $t = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => <<'EOT',
---
---
follows:
    - xxx
    - yyy
EOT
    );
    
    is( "$t", 'DEFAULT@5fe19bbd3a639dc51ca31e186a4f4352c4276449', "stringification ok" );
    ok( ! $t->is_loaded, "DEFAULT starts unloaded" );
    
    # check metadata
    eq_or_diff(
        [ $t->meta( key => 'follows' ) ],
        [ 'xxx', 'yyy' ],
        "metadata parsing in a transform with no rules section",
    );
    
    # check rules
    eq_or_diff(
        [ $t->rules( file => 'files/motd/MAIN' ) ],
        [],
        "rules parsing in a transform with no rules section",
    );
};

# try one with no rules section, but a comment
# this is an example in TransformSyntax.pod
do {
    my $t = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => <<'EOT',
---
# motd:
#   - append rofl
---
follows:
    - xxx
    - yyy
EOT
    );
    
    is( "$t", 'DEFAULT@501cecbcdd3570eda53d768115a3eae6fa3b276b', "stringification ok" );
    ok( ! $t->is_loaded, "DEFAULT starts unloaded" );
    
    # check metadata
    eq_or_diff(
        [ $t->meta( key => 'follows' ) ],
        [ 'xxx', 'yyy' ],
        "metadata parsing in a transform with only a comment in the rules section",
    );
    
    # check rules
    eq_or_diff(
        [ $t->rules( file => 'files/motd/MAIN' ) ],
        [],
        "rules parsing in a transform with only a comment in the rules section",
    );
};

# try one with no meta section
do {
    my $t = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => <<'EOT',
---
motd:
    - append rofl
EOT
    );
    
    is( "$t", 'DEFAULT@8a8d3629de54d5b5ca25fbd4ba4083679f247f75', "stringification ok" );
    ok( ! $t->is_loaded, "DEFAULT starts unloaded" );
    
    # check metadata
    eq_or_diff(
        [ $t->meta( key => 'follows' ) ],
        [],
        "metadata parsing in a transform with no meta section",
    );
    
    # check rules
    eq_or_diff(
        [ $t->rules( file => 'files/motd/MAIN' ) ],
        [ [ 'append', 'rofl' ] ],
        "rules parsing in a transform with metadata",
    );
};

# try one with a bogus meta section
do {
    my $t = Chisel::Transform->new(
        name => 'DEFAULT',
        yaml => <<'EOT',
motd:
    - append rofl

---
follows: xxx
EOT
    );
    
    is( "$t", 'DEFAULT@602e9d69437ff292f075a19da25967013fd0ac5c', "stringification ok" );
    ok( ! $t->is_loaded, "DEFAULT starts unloaded" );
    
    # check metadata
    throws_ok { $t->meta( key => 'follows' ) } qr/meta section is not a key-to-list yaml map/, "metadata parsing in a transform with a bogus metadata section";
    
    # check rules
    throws_ok { $t->rules( file => 'files/motd/MAIN' ) } qr/meta section is not a key-to-list yaml map/, "rules parsing in a transform with a bogus metadata section";
};
