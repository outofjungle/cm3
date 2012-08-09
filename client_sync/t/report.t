#!/var/chisel/bin/perl -w

use warnings;
use strict;
use Fcntl qw/:DEFAULT :flock/;
use File::Temp qw/tempdir/;
use Sys::Hostname;
use Test::More skip_all => "waiting on chisel_get_transport --dir support";

my $hostname    = Sys::Hostname->hostname();
my $report_file = '/var/chisel/var/reports';

# unlink reports file to make sure we're starting with a clean slate
unlink $report_file;

# now report something
ok(
    0 == system(
        '/var/chisel/bin/chisel_get_transport',
        '--dir', '/tmp/', '-r', 'script=motd', '-r', 'version=1234', '-r', 'code=0', '-r', 'runtime=1'
    ),
    'Report (motd,0,1,1234)'
);

# see if json got updated as we'd expect
open( my $fh, $report_file ) or fail( "Couldn't open $report_file" );
my $report = do { local $/; <$fh> };
my $report_exp = '{"motd":[0,1,1234]}';
is( $report, $report_exp, "Report written (motd,0,1,1234)" );

