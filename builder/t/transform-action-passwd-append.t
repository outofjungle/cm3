#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 7 * 4;
use Test::Differences;
use Test::Exception;
use Log::Log4perl;
use ChiselTest::Transform qw/ :all /;

Log::Log4perl->init( 't/files/l4p.conf' );

# append, appendexact, appendunique, prepend are all the same for passwd
foreach my $action ( qw/append appendexact appendunique prepend/ ) {
    transform_test
      name  => "append of passwd text onto empty",
      yaml  => tyaml( [ $action, 'bar:x:2:' ] ),
      from  => "",
      to    => "bar:x:2:\n",
      model => "Passwd";

    transform_test
      name  => "append of passwd text onto existing",
      yaml  => tyaml( [ $action, 'bar:x:2:' ] ),
      from  => "foo:x:1:\n",
      to    => "foo:x:1:\nbar:x:2:\n",
      model => "Passwd";

    transform_test
      name  => "append of passwd text with comments and blank lines",
      yaml  => tyaml( [ $action, "# comment\n\nbar:x:2:\n" ] ),
      from  => "foo:x:1:\n",
      to    => "foo:x:1:\nbar:x:2:\n",
      model => "Passwd";

    transform_test
      name   => "append of conflicting details for the same user",
      yaml   => tyaml( [ $action, "bar:x:2:\n" ] ),
      from   => "foo:x:1:\nbar:x:3:\n",
      throws => qr/'bar' is already present/,
      model  => "Passwd";

    transform_test
      name  => "append of non-conflicting details for the same user",
      yaml  => tyaml( [ $action, "bar:x:3:\n" ] ),
      from  => "foo:x:1:\nbar:x:3:\n",
      to    => "foo:x:1:\nbar:x:3:\n",
      model => "Passwd";

    transform_test
      name   => "append of non-passwd text onto empty",
      yaml   => tyaml( [ $action, 'foo' ] ),
      from   => "",
      throws => qr/append of incorrectly formatted text/,
      model  => "Passwd";

    transform_test
      name   => "append of non-passwd text onto existing",
      yaml   => tyaml( [ $action, 'foo' ] ),
      from   => "foo:x:1:\n",
      throws => qr/append of incorrectly formatted text/,
      model  => "Passwd";
}
