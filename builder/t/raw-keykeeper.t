#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 14;
use Test::Differences;
use Test::Exception;
use Chisel::Builder::Raw::Keykeeper;
use Log::Log4perl;

Log::Log4perl->init( 't/files/l4p.conf' );

# sample data used for various tests
# A = active ; E = employee (both are needed for KK import)
my %users = (
    'aEA' => [
        { content => 'ssh-dss A0 comment has', trust => 'userdb_approved', sudo => 'yes' },
        { content => 'ssh-rsa A1',             trust => 'kk_user', sudo => 'no' }
    ],
    'bE' => [
        { content => 'ssh-dss B0', trust => 'kk_user' },
        { content => 'notakey',    trust => 'kk_user' }
    ],
    'cEA' => [
        { content => 'ssh-dss C0 @noadmin@', trust => 'nfs_imported' },
        { content => 'notakey',              trust => 'kk_user' },
        { content => 'ssh-dss C1',           trust => 'kk_user' },
        { content => 'ssh-dss C2',           trust => 'nfs_imported' },
        { content => '1024 C3',              trust => 'kk_user' },
        { content => 'from="*.example.com" ssh-rsa C4', trust => 'kk_user' }
    ],
    'dA' => [
        { content => 'ssh-dss D0', trust => 'kk_user' },
        { content => '',           trust => 'kk_user' }
    ],
    'e' => [
        { content => 'ssh-dss E0', trust => 'kk_user' }
    ],
    'fEA' => [
        { content => 'ssh-rsa F0', trust => 'kk_user' },
        { content => '',           trust => 'kk_user' }
    ],
);

# test constructor errors
do {
    throws_ok { Chisel::Builder::Raw::Keykeeper->new( xxx => "yyy" ) } qr/Too many parameters/;
    throws_ok { Chisel::Builder::Raw::Keykeeper->new } qr/Please pass in a cmdb::Client as 'cmdb_client'/;
};

# basic tests of the object's methods
do {
    my $kk = Chisel::Builder::Raw::Keykeeper->new(
        cmdb_client              => bless( {}, 'FakecmdbClient' ),
        expiration                => 1234,
        validate_min_user_count   => 2,
        validate_max_user_changes => 2,
    );
    $kk->{keykeeper_obj} = FakeKeykeeperSlurp->new(%users);

    is( $kk->expiration, 1234, "->expiration" );

    my $expected = <<'EOT';
---
aEA:
  - 'LS ssh-dss A0 comment has'
  - 'ssh-rsa A1'
cEA:
  - "from=\"*.example.com\" ssh-rsa C4"
  - 'ssh-dss C1'
fEA:
  - 'ssh-rsa F0'
EOT

    # try a bad fetch
    throws_ok { $kk->fetch("xxx") } qr/unsupported arg \[xxx\]/;

    # try a good fetch
    is( $kk->fetch("homedir"), $expected, "Keykeeper->fetch" );

    # try some validation going towards this new $expected file
    ok( $kk->validate( "homedir", $expected, $expected ), "validation passes when nothing changes" );
    ok( $kk->validate( "homedir", $expected, $expected . <<'EOT' ), "validation passes when change count is low" );
  - 'ssh-rsa F1'
gEA:
  - 'ssh-rsa G0'
  - 'ssh-rsa G1'
EOT

    throws_ok { $kk->validate( "homedir", $expected, undef ) } qr/please manually validate the first import/;
    throws_ok { $kk->validate( "homedir", $expected, "--- {}\n" ) } qr/homedir has too many changes \(3 > 2\)/;
    throws_ok { $kk->validate( "homedir", $expected, $expected . <<'EOT' ) } qr/homedir has too many changes \(3 > 2\)/;
  - 'ssh-rsa F1'
gEA:
  - 'ssh-rsa G0'
  - 'ssh-rsa G1'
hEA:
  - 'ssh-rsa G2'
  - 'ssh-rsa F3'
EOT

    # try going to an empty file
    throws_ok { $kk->validate( "homedir", undef, $expected ) } qr/homedir: blocked removal/;

    my $expected2 = $expected;
    $expected2 =~ s/ssh-/SSH-/g;
    throws_ok { $kk->validate( "homedir", $expected, $expected2 ) } qr/homedir has too many changes \(5 > 2\)/;

    # test validation for some straight-up bad files
    throws_ok { $kk->validate( "homedir", <<'EOT', "--- {}\n" ) } qr/homedir appears to have forbidden accounts/;
root:
  - 'ssh-rsa XX @admin'
aEA:
  - 'ssh-rsa XX @admin'
EOT

    throws_ok { $kk->validate( "homedir", <<'EOT', "--- {}\n" ) } qr/homedir has too few users/;
aEA:
  - 'ssh-rsa XX @admin'
EOT


};

package FakeKeykeeperSlurp;
sub new {
    my ( $class, %args ) = @_;
    bless { users => \%args }, $class;
}
sub users {
    my ( $self ) = @_;
    return keys %{ $self->{users} };
}
sub keys_details {
    my ( $self, $user ) = @_;
    if( $self->{users}{$user} ) {
        return @{ $self->{users}{$user} };
    } else {
        return;
    }
}

package FakecmdbClient;
sub UsersFind {
    my ( $self, %args ) = @_;
    die "was expecting without_pagination" unless $args{'without_pagination'};
    my @ax= map +{
        username  => $_,
        active    => ( scalar( $_ =~ /A/ ) ? '1' : '0' ),
        type      => ( scalar( $_ =~ /E/ ) ? 'employee' : 'headless' ),
        user_type => ( scalar( $_ =~ /E/ ) ? 'individual' : 'headless' ),
      },
      @{ $args{'user'} };
      return @ax;
}
