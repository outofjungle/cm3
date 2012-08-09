package AnyEventDevelCoverHack;

# when AnyEvent does this:
# for (qw(time signal child idle)) {
#    undef &{"AnyEvent::Base::$_"}
#       if defined &{"$MODEL\::$_"};
# }
# it ends up causing segfaults in Devel::Cover, not really sure why

# test program:

# #!/usr/bin/perl
# use strict;
# use warnings;
# use Devel::Cover;
# use AnyEvent;
# use AnyEvent::Util;
#
# my $cv = AnyEvent->condvar;
# $cv->begin;
#
# my @got;
#
# fork_call {
#     my $a = "abc";
#     return $a;
# } sub {
#     push @got, shift;
#     $cv->end;
# };
#
# $cv->recv;
#
# print "end: @got\n";

END { undef *AnyEvent::Base::idle }

1;
