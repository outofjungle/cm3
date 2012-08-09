#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 6;
use lib qw(./lib ../builder/lib ../regexp_lib/lib  ../git_lib/lib ../integrity/lib);
use Chisel::Builder::Engine;
use Chisel::Builder::Engine::Generator;
use Chisel::RawFile;
use Data::Dumper;

Log::Log4perl->init( './t/files/l4p.conf' );

my $files = {
             "raws" => {
                       "file1" => "0000000000000000000000000000000000000001",
                       "file2" => "0000000000000000000000000000000000000002",
                       "file3" => "0000000000000000000000000000000000000003",
                       "file4" => "0100000000000000000000000000000000000001",
                       "file5" => "0100000000000000000000000000000000000002",
                       "file6" => "0100000000000000000000000000000000000003",
                      }
            };

my $engine = Chisel::Builder::Engine->new( application => 'builder' );
$engine->setup;
my $ws = $engine->new_workspace;


my @raws =
  map { Chisel::RawFile->new( name => $_, data => $ws->cat_blob( $files->{'raws'}{$_} ) ) }
  keys %{ $files->{'raws'} };

my $t_ctx = Chisel::Builder::Engine::Generator::Context->new( raws => \@raws );

foreach my $file qw(file1 file2 file3) {
    my $content = $t_ctx->readraw(file => $file);
    chomp($content);    
    ok( $content eq $files->{'raws'}->{$file}, "non-empty file $file ok" );
}

foreach my $file qw(file4 file5 file6) {
    my $content = $t_ctx->readraw(file => $file);
    chomp($content);    
    ok( $content eq "", "empty file $file ok" );
}

no warnings qw(redefine);
package Chisel::Builder::Engine;
sub setup {
    my ( $self, %args ) = @_;
    $self->{is_setup} = 1;
}
sub config {
    return "./t/files";
}
