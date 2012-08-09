#!/usr/bin/perl

# generator-generate.t -- tests generate(), which builds files out of transforms

use warnings;
use strict;
use List::MoreUtils qw/ uniq /;
use ChiselTest::Engine;
use Test::Differences;
use Test::More tests => 4;
use YAML::XS ();

my $engine     = ChiselTest::Engine->new;
my $checkout   = $engine->new_checkout;
my %transforms = map { $_->name => $_ } $checkout->transforms;
my @raws       = $checkout->raw;
my $generator  = $engine->new_generator;

# Generation targets.
my @targets;

# Add transform designed to fail
push @targets, { file => "files/motd/MAIN", transforms => [ @transforms{qw! DEFAULT func/BADBAD DEFAULT_TAIL !} ] };

# Add all files for 'fooqux1' and 'barqux1'
push @targets,
  map +{ file => $_, transforms => [ @transforms{qw! DEFAULT func/FOO func/QUX DEFAULT_TAIL !} ] },
  uniq sort map { $_->files } @transforms{qw! DEFAULT func/FOO func/QUX DEFAULT_TAIL !};
push @targets, map +{ file => $_, transforms => [ @transforms{qw! DEFAULT func/BAR func/QUX DEFAULT_TAIL !} ] },
  uniq sort map { $_->files } @transforms{qw! DEFAULT func/BAR func/QUX DEFAULT_TAIL !};

my $result = $generator->generate(
    raws    => \@raws,
    targets => \@targets,
);

# Check the results of this generation run
# - Shift off and test the one designed to fail
my $err_result = shift @$result;
is( $err_result->{ok},   0,     "error->{ok} = 0" );
is( $err_result->{blob}, undef, "error->{blob} = undef" );
like(
    $err_result->{message},
    qr/file does not exist: nonexistent/,
    "error->{message} =~ /file does not exist: nonexistent/"
);

# - Test files for fooqux1 and barqux1
my %expected = %{ YAML::XS::LoadFile( 't/files/expected.yaml' ) };
eq_or_diff(
    $result,
    [
        # Files for fooqux1
        ( map +{ ok => 1, blob => $expected{'fooqux'}{$_}{'blob'} }, sort keys %{ $expected{'fooqux'} } ),

        # Files for barqux1
        ( map +{ ok => 1, blob => $expected{'barqux'}{$_}{'blob'} }, sort keys %{ $expected{'barqux'} } ),
    ]
);
