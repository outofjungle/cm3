#!/usr/bin/perl -w

# packer-sanity.t -- test integration with a sanity checker ("normally" this is disabled)
#                                                                ^ these quotes are sarcastic because it's always enabled
#                                                                  in prod, but it's disabled in most tests

use strict;
use Log::Log4perl;
use ChiselTest::Engine;
use Test::Differences;
use Test::More tests => 6;

Log::Log4perl->init( 't/files/l4p.conf' );

# Create mock socket, using tied filehandle
my $socket_obj = tie *FAKESOCKET, 'FakeSanitySocket', expect => [
    {
        t => '>',
        d => "bl 3\nh1\n\n" .    # NODELIST
          "bl 5\nLOLOL\n" .              # REPO
          "bl 5\n1234\n\n" .             # VERSION
          "bl 12\nhello world\n\n" .     # files/motd/MAIN
          "bl 13\nDefaults xxx\n\n" .    # files/sudoers/MAIN
          "ck 571\n" . <<EOT . "\n"
{"mode":"0644","name":["MANIFEST"],"type":"file"}
{"mode":"0644","name":["MANIFEST.asc"],"type":"file"}
{"md5":"ebf87910a640739c7e16d28f2a590735","mode":"0644","name":["NODELIST"],"type":"file"}
{"md5":"926b4f09ba7ffc48a4004c857e2e0cb3","mode":"0644","name":["REPO"],"type":"file"}
{"md5":"e7df7cd2ca07f4f1ab415d457a6e1c13","mode":"0644","name":["VERSION"],"type":"file"}
{"md5":"6f5902ac237024bdd0c176cb93063dc4","mode":"0644","name":["files/motd/MAIN"],"type":"file"}
{"md5":"f0f47eb42d8db410894c7811e8d41516","mode":"0644","name":["files/sudoers/MAIN"],"type":"file"}
EOT
    },
    { t => '<', d => "no ERROR MESSAGE GOES HERE\nTHEY ARE FUN TO READ!\n\0" },
    {
        t => '>',
        d => "bl 3\nh2\n\n" .    # NODELIST
          "bl 13\nDefaults yyy\n\n" .    # files/sudoers/MAIN
          "ck 571\n" . <<EOT . "\n"
{"mode":"0644","name":["MANIFEST"],"type":"file"}
{"mode":"0644","name":["MANIFEST.asc"],"type":"file"}
{"md5":"4217c1ce78c1e6bae73fe12ce19c51d3","mode":"0644","name":["NODELIST"],"type":"file"}
{"md5":"926b4f09ba7ffc48a4004c857e2e0cb3","mode":"0644","name":["REPO"],"type":"file"}
{"md5":"e7df7cd2ca07f4f1ab415d457a6e1c13","mode":"0644","name":["VERSION"],"type":"file"}
{"md5":"6f5902ac237024bdd0c176cb93063dc4","mode":"0644","name":["files/motd/MAIN"],"type":"file"}
{"md5":"0fbff06878e0a532688b95dee7236a2a","mode":"0644","name":["files/sudoers/MAIN"],"type":"file"}
EOT
    },
    { t => '<', d => "ok -----BEGIN PGP SIGNATURE-----\nWOOOOO\n-----END PGP SIGNATURE-----\n" },
];

my $socket = \*FAKESOCKET;

# Create the Packer
my $engine = ChiselTest::Engine->new;
my $packer = $engine->new_packer( sanity_socket => $socket, );

# Store these blobs to git (since the packer will need to read them out)
$packer->workspace->store_blob( "hello world\n" );
$packer->workspace->store_blob( "Defaults xxx\n" );
$packer->workspace->store_blob( "Defaults yyy\n" );

# Run the Packer
my $result = $packer->pack(
    version => 1234,
    repo => "LOLOL",
    targets => [
        {
            hosts => ["h1"],
            files => [
                {
                    # "hello world\n"
                    name => 'files/motd/MAIN',
                    blob => '3b18e512dba79e4c8300dd08aeb37f8e728b8dad',
                },
                {
                    # "Defaults xxx\n"
                    name => 'files/sudoers/MAIN',
                    blob => 'fe02a6c668a9a0695d4ab235f84c7cd3909de494',
                },
            ],
        },
        {
            hosts  => ["h2"],
            files => [
                {
                    # "hello world\n"
                    name => 'files/motd/MAIN',
                    blob => '3b18e512dba79e4c8300dd08aeb37f8e728b8dad',
                },
                {
                    # "Defaults yyy\n"
                    name => 'files/sudoers/MAIN',
                    blob => 'c713d034a87d87998732716fb44dc164852b9fde',
                },
            ],
        },
    ],
);

# Confirm sanity checker was called as expected
ok( $socket_obj->ok, "Packer/Sanity script played out as expected" );

# Confirm results
is( scalar @$result,    2, '@$result == 2' );
is( $result->[0]{'ok'}, 0, '$result->[0]{ok}' );
is(
    $result->[0]{'message'},
    "Sanity check failed!\nERROR MESSAGE GOES HERE\nTHEY ARE FUN TO READ!\n",
    '$result->[0]{message}'
);
is( $result->[1]{'ok'}, 1, '$result->[1]{ok}' );
like(
    $packer->workspace->cat_blob(
        $packer->workspace->bucket( $result->[1]{'bucket'} )->manifest( emit => ['blob'] )
          ->{'MANIFEST.asc'}{'blob'}
    ),
    qr/-----BEGIN PGP SIGNATURE-----\nWOOOOO\n-----END PGP SIGNATURE-----\n/,
    '$result->[1] MANIFEST.asc'
);

package FakeSanitySocket;

use Log::Log4perl qw/ :easy /;

sub TIEHANDLE {
    my ( $class, %args ) = @_;
    bless { buf => '', expect => [], %args }, $class;
}

sub PRINT {
    my ( $self, @args ) = @_;
    $self->{buf} .= join( ( $, || '' ), @args );
    DEBUG "PRINT: buf = [$self->{buf}]";
}

sub READLINE {
    my ( $self ) = @_;

    if( $/ ne "\0" ) {
        die "Unexpected READLINE separator (ord " . ord( $/ ) . " aka $/)";
    }

    # check existing buf against expectations
    if( length $self->{buf} && $self->{expect}[0]{t} eq '>' && $self->{expect}[0]{d} eq $self->{buf} ) {
        # matches expectations. remove it from 'expect' and 'buf'
        $self->{buf} = '';
        shift @{ $self->{expect} };
    }

    # check if we should be writing something now
    if( $self->{expect}[0]{t} eq '<' ) {
        my $d = $self->{expect}[0]{d};
        shift @{ $self->{expect} };
        DEBUG "READLINE: d = $d";
        return $d;
    } else {
        die "Unexpected READLINE call";
    }
}

# test is OK if expect has been totally flushed and 'buf' is empty
sub ok {
    my ( $self ) = @_;
    return @{ $self->{expect} } == 0 && length $self->{buf} == 0 ? 1 : 0;
}
