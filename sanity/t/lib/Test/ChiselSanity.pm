package Test::chiselSanity;

use strict;
use warnings;
use Test::More;
use File::Temp qw/ tempdir /;
use Chisel::Sanity;

use Exporter qw/import/;
our @EXPORT_OK = qw/ new_sanity /;
our %EXPORT_TAGS = ( "all" => [@EXPORT_OK], );

sub new_sanity { # creates a new builder with test defaults + maybe some overrides / additions
    my ( %args ) = @_;

    my $tmp = tempdir( CLEANUP => 1 );

    # set up a tmp scratch dir
    system( "cd $tmp && mkdir scratch" );

    # fill gnupghome
    mkdir "$tmp/gnupghome";
    chmod 0700, "$tmp/gnupghome";
    system "gpg --homedir $tmp/gnupghome --import ../integrity/t/files/keyrings/autoring.asc ../integrity/t/files/keyrings/autoring-sec.asc 2>&1 >/dev/null";
    system "cp $tmp/gnupghome/pubring.gpg $tmp/gnupghome/trustedkeys.gpg";

    my $sanity = Chisel::Sanity->new(
        scriptdir => "t/files/modules.0",
        tmpdir    => "$tmp/scratch",
        gnupghome => "$tmp/gnupghome",
        %args,
    );

    return wantarray ? ( $sanity, $tmp ) : $sanity;
}
