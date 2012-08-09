#!/usr/bin/perl

# packer-pack.t -- tests pack(), which builds buckets out of generated files

use warnings;
use strict;
use List::MoreUtils qw/ uniq /;
use ChiselTest::Engine;
use Test::Differences;
use Test::More tests => 5;
use YAML::XS ();

# Buckets to pack.
my %expected  = %{ YAML::XS::LoadFile( 't/files/expected.yaml' ) };

my @targets = (
    # fooqux bucket from expected.yaml
    {
        hosts => [ "fooqux1", "fooqux2" ],
        files => [
            { name => '.dot/fi <le', blob => 'bd8ccf53ac7204dde48cbc21104c06c18bd9ad01'}, # "hai guyz\n"
            map +{ name => $_->{'file'}, blob => $_->{'blob'} },
            grep { defined $_->{'blob'} } values %{ $expected{'fooqux'} }
        ],
    },

    # barqux bucket from expected.yaml
    {
        hosts   => [ "barqux1", "barqux2" ],
          files => [
            map +{ name => $_->{'file'}, blob => $_->{'blob'} },
            grep { defined $_->{'blob'} } values %{ $expected{'barqux'} }
          ],
    },
);

# Create Packer object.
my $engine = ChiselTest::Engine->new;
my $packer = $engine->new_packer;

# Store these blobs to git (since the packer will need to read them out)
$packer->workspace->store_blob( "hai guyz\n" ); # for ".dot/fi <le"
$packer->workspace->store_blob( $_->{'contents'} )
  for grep { defined $_->{'contents'} } values %{ $expected{'fooqux'} }, values %{ $expected{'barqux'} };

# Run these targets.
my $result = $packer->pack( targets => \@targets, version => 1234, repo => "LOLOL", );

# Confirm they came back OK
is( scalar @$result,    2, '@$result == 2' );
is( $result->[0]{'ok'}, 1, '$result->[0]{ok} == 1' );
is( $result->[1]{'ok'}, 1, '$result->[1]{ok} == 1' );

# Ensure the returned buckets are retrievable from the workspace, and have correct file lists
my $fooqux_ret = $packer->workspace->bucket( $result->[0]{'bucket'} );
my $barqux_ret = $packer->workspace->bucket( $result->[1]{'bucket'} );

eq_or_diff(
    [
        sort map { "$_->{name}:$_->{blob}" }
          values %{ $fooqux_ret->manifest( emit => ['blob'], skip => ['MANIFEST.asc'], include_dotfiles => 1 ) }
    ],
    [
        '.dot/fi <le:bd8ccf53ac7204dde48cbc21104c06c18bd9ad01',
        'MANIFEST:' . $packer->workspace->git_sha( 'blob', <<'EOT' ),
{"mode":"0644","name":["MANIFEST"],"type":"file"}
{"mode":"0644","name":["MANIFEST.asc"],"type":"file"}
{"md5":"e2e0a773e17e2d69481e3a4718f6aa3c","mode":"0644","name":["NODELIST"],"type":"file"}
{"md5":"926b4f09ba7ffc48a4004c857e2e0cb3","mode":"0644","name":["REPO"],"type":"file"}
{"md5":"e7df7cd2ca07f4f1ab415d457a6e1c13","mode":"0644","name":["VERSION"],"type":"file"}
{"md5":"6191d639db25fc9ab2d23f5562419bcb","mode":"0644","name":["files/motd/MAIN"],"type":"file"}
{"md5":"45e8436644d696a12ebc5f83664ea43c","mode":"0644","name":["files/passwd/MAIN"],"type":"file"}
{"md5":"8369daa337481804930d6ce9ac8ce17f","mode":"0644","name":["files/passwd/freebsd"],"type":"file"}
{"md5":"bd61516ae6212b0b627359e42d67c2dd","mode":"0644","name":["files/passwd/linux"],"type":"file"}
{"md5":"476150db5b3103542c3dabff1b01848e","mode":"0644","name":["files/passwd/shadow"],"type":"file"}
{"md5":"d41d8cd98f00b204e9800998ecf8427e","mode":"0644","name":["files/quxfile/MAIN"],"type":"file"}
{"md5":"3d872aa801337b37352de475fc2298bd","mode":"0755","name":["scripts/passwd"],"type":"file"}
EOT
        'NODELIST:' . $packer->workspace->git_sha( 'blob', "fooqux1\nfooqux2\n" ),
        'REPO:' . $packer->workspace->git_sha( 'blob', "LOLOL" ),
        'VERSION:' . $packer->workspace->git_sha( 'blob', "1234\n" ),
        (
            map  { "$_:$expected{fooqux}{$_}{blob}" }
            grep { $expected{'fooqux'}{$_}{'blob'} } sort keys %{ $expected{'fooqux'} }
        ),
    ]
);

eq_or_diff(
    [
        sort map { "$_->{name}:$_->{blob}" }
          values %{ $barqux_ret->manifest( emit => ['blob'], skip => ['MANIFEST.asc'], include_dotfiles => 1 ) }
    ],
    [
        'MANIFEST:' . $packer->workspace->git_sha( 'blob', <<'EOT' ),
{"mode":"0644","name":["MANIFEST"],"type":"file"}
{"mode":"0644","name":["MANIFEST.asc"],"type":"file"}
{"md5":"d983080cfd2e08486410720cfa0ccfbb","mode":"0644","name":["NODELIST"],"type":"file"}
{"md5":"926b4f09ba7ffc48a4004c857e2e0cb3","mode":"0644","name":["REPO"],"type":"file"}
{"md5":"e7df7cd2ca07f4f1ab415d457a6e1c13","mode":"0644","name":["VERSION"],"type":"file"}
{"md5":"fcb4792367e0489bc3aab06e6f52b619","mode":"0644","name":["files/motd/MAIN"],"type":"file"}
{"md5":"45e8436644d696a12ebc5f83664ea43c","mode":"0644","name":["files/passwd/MAIN"],"type":"file"}
{"md5":"b0ad846af82717dc1643f248cdb3c3a1","mode":"0644","name":["files/passwd/freebsd"],"type":"file"}
{"md5":"dd49cd0105b799c11ffa3d11ca52141e","mode":"0644","name":["files/passwd/linux"],"type":"file"}
{"md5":"f2993ccae8e8a7b6d82420f1b6a64b9d","mode":"0644","name":["files/passwd/shadow"],"type":"file"}
{"md5":"d41d8cd98f00b204e9800998ecf8427e","mode":"0644","name":["files/quxfile/MAIN"],"type":"file"}
{"md5":"0bcc402f70498c7860f41332d79e4339","mode":"0644","name":["files/sudoers/MAIN"],"type":"file"}
{"md5":"3d872aa801337b37352de475fc2298bd","mode":"0755","name":["scripts/passwd"],"type":"file"}
EOT
        'NODELIST:' . $packer->workspace->git_sha( 'blob', "barqux1\nbarqux2\n" ),
        'REPO:' . $packer->workspace->git_sha( 'blob', "LOLOL" ),
        'VERSION:' . $packer->workspace->git_sha( 'blob', "1234\n" ),
        (
            map  { "$_:$expected{barqux}{$_}{blob}" }
            grep { $expected{'barqux'}{$_}{'blob'} } sort keys %{ $expected{'barqux'} }
        ),
    ]
);

exit 0;
