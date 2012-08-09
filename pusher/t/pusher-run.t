#!/usr/local/bin/perl
use warnings;
use strict;
use Test::More tests => 13;
use Log::Log4perl;
use DBI;
use lib qw(./lib ../builder/lib ../regexp_lib/lib ../git_lib/lib ../integrity/lib);
use Chisel::Pusher;
use Data::Dumper;

Log::Log4perl->init( './t/files/l4p.conf' );

ok( system("./t/mkdb") == 0 , "creating test db");
my $dbh = DBI->connect("dbi:SQLite:dbname=./t/.db/test.db","foo","");

sub fetch_hostnames {
    my @hosts = map { $_->[0] } @{$dbh->selectall_arrayref( 'SELECT hostname FROM hosts' )};
    return sort( @hosts ); 
}

sub wipe_hostnames {
    $dbh->do("DELETE FROM hosts");
    my @hosts = fetch_hostnames();
    ok( 0 == scalar( @hosts ), "wipe succeeded" );
}

our $members = [
                "bogus1.member.foo.com",
                "bogus2.member.foo.com"
               ];

my $pusher = Chisel::Pusher->new(
                                     pushtar => "./t/files/pushtar.tar",
                                     role => "bogus.role",
                                     push_throttle => 1
                                    );

$pusher->run( once => 1 );
my @hosts = fetch_hostnames();
ok( join(",", @hosts) eq "bogus1.member.foo.com,bogus2.member.foo.com" );
wipe_hostnames();

pop @{$members};
$pusher->run( once => 1 );
@hosts = fetch_hostnames();
ok( join(",", @hosts) eq "" );
wipe_hostnames();

$pusher->{hosttime}->{"bogus1.member.foo.com"} = 0;
$pusher->run( once => 1 );
@hosts = fetch_hostnames();
ok( join(",", @hosts) eq "bogus1.member.foo.com" );
wipe_hostnames();

$pusher->{hosttime}->{"bogus1.member.foo.com"} = 0;
push @{$members}, "new1.member.foo.com";
$pusher->run( once => 1 );
@hosts = fetch_hostnames();
ok( join(",", @hosts) eq "bogus1.member.foo.com,new1.member.foo.com" );
wipe_hostnames();

$pusher->{hosttime} = {};
$pusher->{hosttime}->{"new1.member.foo.com"} = time;
$members = ["new1.member.foo.com", "new2.member.foo.com"];
$pusher->run( once => 1 );
@hosts = fetch_hostnames();
ok( join(",", @hosts) eq "new2.member.foo.com" );
wipe_hostnames();

map { $pusher->{hosttime}->{$_} = 0 } keys %{$pusher->{hosttime}};
pop @{$members};
$pusher->run( once => 1 );
@hosts = fetch_hostnames();
ok( join(",", @hosts) eq "new1.member.foo.com" );
wipe_hostnames();
$pusher->run( once => 1 );

#
# Stubs
#
no warnings qw(redefine);
package Chisel::Builder::Engine;
sub new {
    my ( $class, %config ) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}
sub roles {
    return Group::Client->new();
}

package Group::Client;
sub role {
    return { members => $members };
}

package Chisel::Pusher;
sub push_single {
    my ($self, $hostname) = @_;
    my $sth = $dbh->prepare("INSERT INTO hosts (hostname) VALUES (?)");
    $sth->execute( $hostname );
    return 1;
}
