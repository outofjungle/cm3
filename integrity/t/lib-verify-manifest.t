#!/usr/local/bin/perl -w

# tests the "verify_manifest" function in Chisel::Integrity

use warnings;
use strict;
use Test::More tests => 14;
use Test::chiselVerify qw/:all/;
use File::Temp qw/tempdir/;
use Chisel::Integrity;

my $m = Chisel::Integrity->new( gnupghome => '/nonexistent' );
my $tmp = tempdir( CLEANUP => 1 );

my $fixtures = fixtures();
system "cp -r $fixtures/bucket $tmp/bucket";

my $manifest = <<END;
{"mode":"0644","name":["README"],"type":"file","md5":"1fd09ca44e561bbd4d88f0520b064e51"}
{"mode":"0644","name":["file"],"type":"file","md5":"44f68f975f86a16ef90092612c0cbf9c"}
{"mode":"0644","name":["file2"],"type":"file","md5":"1a0fa6617199773604044934e04b52d3"}
{"mode":"0644","name":["MANIFEST"],"type":"file"}
END

# write manifest
my $mf = "$tmp/bucket/MANIFEST";
write_file( file => $mf, contents => "$manifest" );

# sign it
ok( -f $mf );

# should be ok at first
ok( $m->verify_manifest( dir => "$tmp/bucket" ), "manifest is verifiable" );

# tweak a non-manifest file
system "echo xxx > $tmp/bucket/file";
ok( !$m->verify_manifest( dir => "$tmp/bucket" ), "modified file invalidates manifest itself" );

# fix the manifest to reflect the tweaked file
$manifest =~ s/44f68f975f86a16ef90092612c0cbf9c/6de9439834c9147569741d3c9c9fc010/;
write_file( file => $mf, contents => "$manifest" );

ok( $m->verify_manifest( dir => "$tmp/bucket" ), "correcting manifest fixes it" );

# sign it, should be ok again
ok( $m->verify_manifest( dir => "$tmp/bucket" ), "manifest is still accurate after re-signing" );

# sign with chiselsanity as well
ok( $m->verify_manifest( dir => "$tmp/bucket" ), "manifest is still valid after adding a signature" );

# sign it, should be ok again
ok( $m->verify_manifest( dir => "$tmp/bucket" ), "manifest is accurate after re-signing" );

# add a new file, should break verification
system "echo xxx > $tmp/bucket/new_file";
ok( !$m->verify_manifest( dir => "$tmp/bucket" ), "adding an extra non-dot file invalidates manifest" );

# move it to a dotfile, verification should still be broken
my $r = rename "$tmp/bucket/new_file" => "$tmp/bucket/.new_file";
ok( $r );
ok( !$m->verify_manifest( dir => "$tmp/bucket" ), "adding an extra dotfile invalidates manifest" );

# remove the extra file
unlink "$tmp/bucket/.new_file";
ok( $m->verify_manifest( dir => "$tmp/bucket" ), "manifest is okay again after removing extra file" );

# change mode of an existing file
chmod 0755, "$tmp/bucket/README";
ok( !$m->verify_manifest( dir => "$tmp/bucket" ), "manifest is invalid after changing file mode" );
chmod 0644, "$tmp/bucket/README";
ok( $m->verify_manifest( dir => "$tmp/bucket" ), "manifest is okay after restoring file mode" );

# remove a file
unlink "$tmp/bucket/README";
ok( !$m->verify_manifest( dir => "$tmp/bucket" ), "manifest is invalid after deleting a file" );

sub write_file {
    my %args = @_;
    open my $fh, ">", $args{file} or die;
    print $fh $args{contents};
    close $fh or die;
}
