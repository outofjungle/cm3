#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 136;
use Test::Differences;
use Test::Exception;
use File::Temp qw/tempdir/;
use Log::Log4perl;
use Chisel::CheckoutPack;
use Chisel::RawFile;
use Chisel::Transform;

Log::Log4perl->init( 't/files/l4p.conf' );

my $tmp = tempdir( CLEANUP => 1 );
my $tarfile = "$tmp/cp.tar";

my $cp = Chisel::CheckoutPack->new( filename => $tarfile );
my $cpe = $cp->extract;

# read from the nonexistent tarball
is( $cp->filename,       $tarfile, "[nonexistent] filename correct" );
is( $cpe->version,       undef,    "[nonexistent] version = undef" );
is( $cpe->raw( "name" ), undef,    "[nonexistent] raw(name) = undef" );
eq_or_diff( [ $cpe->host_transforms( "foo" ) ], [], "[nonexistent] host_transforms(foo) = ()" );

# data we'd like to insert
my $t1  = Chisel::Transform->new( name => "some/role",     yaml => "motd: [ 'append t1' ]\n" );
my $t2a = Chisel::Transform->new( name => "your/role",     yaml => "motd: [ 'append t2a' ]\n" );
my $t2b = Chisel::Transform->new( name => "your/role",     yaml => "motd: [ 'append t2b' ]\n" );
my $t3  = Chisel::Transform->new( name => "yourmoms/role", yaml => "motd: [ 'append t3' ]\n" );

my %raw_blob = (
    "motd"                           => "15e0c2b202548d137685522cab2ffd980309e7de",
    "cmdb_usergroup/bad_users"      => "4a7e3a0bede330c828ee9ab07e828412603cba77",
    "cmdb_usergroup/empty_users"    => "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391",
    "cmdb_usergroup/good_users"     => "423ba8d310c402830a43ead00c143608a2bed7a8",
    "passwd"                         => "358d38c3f4f4da0ac19c985ce7e2b4b3f65de47b",
    "rawtest"                        => "e5c5c5583f49a34e86ce622b59363df99e09d4c6",
    "rawtest2"                       => "9f5ad239f7ac666d757abe9c8189fc3b96b944a8",
    "group_role/bad.test.role"     => "e42ee8c793e0f1dcfd40a3a3d02e7776c979c02e",
    "group_role/binary.test.role"  => "8c8c0b4336192e56423048c7a7b604e722fe579e",
    "group_role/binary.test.role2" => "da4a2cf0e9264872754a26180a2141191ab8c151",
    "group_role/empty.test.role"   => "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391",
    "group_role/ginormous"         => "25c23579d87117f83a6b9e470c1f6cb819937be7",
    "group_role/good.test.role"    => "315d1c4d4504afd2dfe4cd7d598357c7d7344d3c",
    "group_role/huge"              => "6efd6bf711861f2b87c8b6a69fb415d1cf58b64d",
    "unicode"                        => "3bd9332979a3df80935ccef4d92e25c928879353",
);

my %raw_data = map {
    $_ => do { open my $fh, "<", "t/files/configs.1/raw/$_"; local $/; scalar <$fh> }
} keys %raw_blob;

for my $raw_pattern ( qr/^(?!group_role)/, qr/^(?!)cmdb_usergroup/ ) {
    $cpe->smash(
        host_transforms => {
            'some.host.name' => [ $t1, $t2a, $t3 ],
            'your.host.name' => [ $t1, $t2b ],
        },
        raws => [
            map { Chisel::RawFile->new( name => $_, data => $raw_data{$_}, ) }
            grep { /$raw_pattern/ } keys %raw_blob
        ],
    );

    $cp->write_from_fs( $cpe->stagedir );

    # test that raw files came out correctly both in the original extracted object ($cpe)
    # and if we re-extract the tarball ($cpe2 = $cp->extract)
    my $cpe2 = $cp->extract;
    for my $raw_name ( keys %raw_blob ) {
        if( $raw_name =~ /$raw_pattern/ ) {
            # raw file should exist
            my $cpe_raw        = $cpe->raw( $raw_name );
            my $cp_extract_raw = $cpe2->raw( $raw_name );

            is( $cpe->raw_blob( $raw_name ),  $raw_blob{$raw_name}, "cpe->raw_blob($raw_name)" );
            is( $cpe2->raw_blob( $raw_name ), $raw_blob{$raw_name}, "cp->extract->raw_blob($raw_name)" );

            is( $cpe_raw->blob,        $raw_blob{$raw_name}, "cpe->raw($raw_name) blob" );
            is( $cp_extract_raw->blob, $raw_blob{$raw_name}, "cp->extract->raw($raw_name) blob" );

            is( $cpe_raw->data,        $raw_data{$raw_name}, "cpe->raw($raw_name) data" );
            is( $cp_extract_raw->data, $raw_data{$raw_name}, "cp->extract->raw($raw_name) data" );
        } else {
            # raw file should not exist
            is( $cpe->raw_blob( $raw_name ),    undef, "cpe->raw_blob($raw_name)" );
            is( $cpe->raw( $raw_name ),         undef, "cpe->raw($raw_name)" );
            is( $cp->extract->raw( $raw_name ), undef, "cp->extract->raw($raw_name)" );
        }
    }
}

# test that host -> transform map came out correctly
my $cpe2 = $cp->extract;
eq_or_diff(
    [ $cpe->host_transforms( 'some.host.name' ) ],
    [
        'some/role@2043507676dcfb252a0c1c03c70dd36a7c035bd8',
        'your/role@e0d68f88ebea7b61281e354078c7ffb921cd0dc8',
        'yourmoms/role@afbc5d67d64ffbd3ea5378695cfd40e72cff4909'
    ],
    "cpe->host_transforms(some.host.name)"
);
eq_or_diff(
    [ $cpe2->host_transforms( 'some.host.name' ) ],
    [
        'some/role@2043507676dcfb252a0c1c03c70dd36a7c035bd8',
        'your/role@e0d68f88ebea7b61281e354078c7ffb921cd0dc8',
        'yourmoms/role@afbc5d67d64ffbd3ea5378695cfd40e72cff4909'
    ],
    "cp->extract->host_transforms(some.host.name)"
);
eq_or_diff(
    [ $cpe->host_transforms( 'your.host.name' ) ],
    [ 'some/role@2043507676dcfb252a0c1c03c70dd36a7c035bd8', 'your/role@2dba57378a0e3959b2dfdf07be5bbbbea5157a6e' ],
    "cpe->host_transforms(your.host.name)"
);
eq_or_diff(
    [ $cpe2->host_transforms( 'your.host.name' ) ],
    [ 'some/role@2043507676dcfb252a0c1c03c70dd36a7c035bd8', 'your/role@2dba57378a0e3959b2dfdf07be5bbbbea5157a6e' ],
    "cp->extract->host_transforms(your.host.name)"
);
eq_or_diff( [ $cpe->host_transforms( 'bogus.host.name' ) ],  [], "cpe->host_transforms(bogus.host.name)" );
eq_or_diff( [ $cpe2->host_transforms( 'bogus.host.name' ) ], [], "cp->extract->host_transforms(bogus.host.name)" );

# test that transform objects come out correct
eq_or_diff( $cpe->transform( 'your/role@2dba57378a0e3959b2dfdf07be5bbbbea5157a6e' ), $t2b );

# test bad transform objects
throws_ok { $cpe->transform( 'your/role@xxx' ) } qr/Invalid transform id/;

# test version method
ok( $cpe->version > 0, "version > 0" );
