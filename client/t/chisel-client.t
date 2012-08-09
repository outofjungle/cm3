#!/var/chisel/bin/perl -w

use warnings;
use strict;
use Cwd ();
use Test::More tests => 10;
use Test::ChiselClient qw/:all/;

my %expected = ( 'OUT' => "test file contents\n" );

# --directory needs an absolute path
my $directory = Cwd::getcwd() . "/t/data";

client_ok( [ "--once", "--directory=$directory" ] );
scratch_is( \%expected );

client_ok( [ "--once", "--run=test", "--directory=$directory" ] );
scratch_is( \%expected );

client_dies( [ "--once", "--run=nonexistent", "--directory=$directory" ] );
scratch_is( {}, "scratch should be clean when running nonexistent scripts" );

client_dies( [ "--once", "--run=nonexistent,test", "--directory=$directory" ] );
scratch_is( \%expected, "scratch should have the one script that worked even if there was a failure" );

client_dies( [ "--once", "--run=test,nonexistent", "--directory=$directory" ] );
scratch_is( \%expected, "scratch should have the one script that worked even if there was a failure (reverse order)" );
