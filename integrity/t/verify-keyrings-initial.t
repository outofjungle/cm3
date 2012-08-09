#!/usr/local/bin/perl -w

# tests that when "chisel_verify" is used, keyrings are copied from x.initial.gpg to x.gpg

use warnings;
use strict;
use Test::More tests => 14;
use Test::chiselVerify qw/:all/;

my $gnupghome = gnupghome();
my $fixtures = fixtures();
my $cvargs = "-S $fixtures/bucket.normal/scripts/motd";

# Initial set - move keys to autoring.initial.gpg and hurmanring.initial.gpg since IntegritySetUp.pm imports them as the real key.
ok( -e "$gnupghome/autoring.gpg" &&  -e "$gnupghome/humanring.gpg");
system "mv $gnupghome/autoring.gpg $gnupghome/autoring.initial.gpg";
system "mv $gnupghome/humanring.gpg $gnupghome/humanring.initial.gpg";
ok( !-e "$gnupghome/autoring.gpg" && !-e "$gnupghome/humanring.gpg");




#should execute clean and copy the .initial.gpg to .gpg
verify_ok($cvargs);
ok( -e "$gnupghome/autoring.gpg" && -e "$gnupghome/humanring.gpg");

# test if file gets modified. It should not.
my $autoring_saved_mtime = ( stat "$gnupghome/autoring.initial.gpg" )[9];
my $humanring_saved_mtime = ( stat "$gnupghome/humanring.initial.gpg" )[9];
verify_ok($cvargs);
ok( ( stat "$gnupghome/autoring.initial.gpg" )[9]  == $autoring_saved_mtime);
ok( ( stat "$gnupghome/humanring.initial.gpg" )[9] == $humanring_saved_mtime);


# rename both autoring files. This should cause the script to fail
system "mv $gnupghome/autoring.gpg $gnupghome/autoring.moved";
system "mv $gnupghome/autoring.initial.gpg $gnupghome/autoring.initial.moved";
verify_dies($cvargs);
system "mv $gnupghome/autoring.moved $gnupghome/autoring.gpg";
system "mv $gnupghome/autoring.initial.moved $gnupghome/autoring.initial.gpg";

# rename both humanring files. This should cause the script to fail
system "mv $gnupghome/humanring.gpg $gnupghome/humanring.moved";
system "mv $gnupghome/humanring.initial.gpg $gnupghome/humanring.initial.moved";
verify_dies($cvargs);
system "mv $gnupghome/humanring.moved $gnupghome/humanring.gpg";
system "mv $gnupghome/humanring.initial.moved $gnupghome/humanring.initial.gpg";


# rename all files. This should cause the script to fail
system "mv $gnupghome/autoring.gpg $gnupghome/autoring.moved";
system "mv $gnupghome/autoring.initial.gpg $gnupghome/autoring.initial.moved";
system "mv $gnupghome/humanring.gpg $gnupghome/humanring.moved";
system "mv $gnupghome/humanring.initial.gpg $gnupghome/humanring.initial.moved";
verify_dies($cvargs);


# final fix up
system "mv $gnupghome/autoring.moved $gnupghome/autoring.gpg";
system "mv $gnupghome/autoring.initial.moved $gnupghome/autoring.initial.gpg";
system "mv $gnupghome/humanring.moved $gnupghome/humanring.gpg";
system "mv $gnupghome/humanring.initial.moved $gnupghome/humanring.initial.gpg";
verify_ok($cvargs);


# mangle the key file and make sure it is not replaced by
system "echo xxx > $gnupghome/autoring.gpg";
system "echo xxx > $gnupghome/humanring.gpg";
$autoring_saved_mtime = ( stat "$gnupghome/autoring.gpg" )[9];
$humanring_saved_mtime = ( stat "$gnupghome/humanring.gpg" )[9];
verify_dies($cvargs);
ok( ( stat "$gnupghome/autoring.gpg" )[9]  == $autoring_saved_mtime);
ok( ( stat "$gnupghome/humanring.gpg" )[9] == $humanring_saved_mtime);


