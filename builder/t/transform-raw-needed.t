#!/usr/bin/perl

# transform-raw-needed.t -- test that the raw_needed function in transform models works as advertised

use warnings;
use strict;
use Test::More tests => 42;
use Test::Differences;
use Log::Log4perl;
use Carp ();

use Chisel::TransformModel;
use Chisel::TransformModel::Group;
use Chisel::TransformModel::Iptables;
use Chisel::TransformModel::Passwd;
use Chisel::TransformModel::Text;

Log::Log4perl->init( 't/files/l4p.conf' );

my $model_group  = Chisel::TransformModel::Group->new;
my $model_passwd = Chisel::TransformModel::Passwd->new;
my $model_text   = Chisel::TransformModel::Text->new;
my $model_ipt    = Chisel::TransformModel::Iptables->new;

# Passwd 'add' should depend on 'passwd'
eq_or_diff( ['passwd'], [ $model_passwd->raw_needed( 'add', 'jack, jill' ) ] );
eq_or_diff( ['passwd'], [ $model_passwd->raw_needed( 'add', 'jack', 'jill' ) ] );

# Group 'add' should depend on 'group'
eq_or_diff( ['group'], [ $model_group->raw_needed( 'add', 'jack, jill' ) ] );
eq_or_diff( ['group'], [ $model_group->raw_needed( 'add', 'jack', 'jill' ) ] );

# Similar for 'srsadd', 'give_me_all_users', and 'give_me_all_groups'
eq_or_diff( ['passwd'], [ $model_passwd->raw_needed( 'srsadd', 'jack, jill' ) ] );
eq_or_diff( ['passwd'], [ $model_passwd->raw_needed( 'give_me_all_users' ) ] );
eq_or_diff( ['group'], [ $model_group->raw_needed( 'srsadd', 'jack, jill' ) ] );
eq_or_diff( ['group'], [ $model_group->raw_needed( 'give_me_all_groups' ) ] );

# Iptables 'host' should depend on 'dns/hostname'
eq_or_diff( ['dns/foo.fake-domain.com'], [ $model_ipt->raw_needed( 'accept', 'host foo.fake-domain.com' ) ] );

# Iptables 'role' should depend on 'dns/role:rolename'
eq_or_diff( ['dns/role:foo.bar'], [ $model_ipt->raw_needed( 'accept', 'role foo.bar port 11211/tcp' ) ] );

# in all models:
foreach my $model ( $model_group, $model_passwd, $model_text ) {
    # 'include', 'use', and 'invokefor' depend on their first argument
    eq_or_diff( ['blah/foo.bar'], [ $model->raw_needed( 'include',   'blah/foo.bar' ) ] );
    eq_or_diff( ['blah/foo.bar'], [ $model->raw_needed( 'use',       'blah/foo.bar' ) ] );
    eq_or_diff( ['blah/foo.bar'], [ $model->raw_needed( 'invokefor', 'blah/foo.bar', 'append', '{}' ) ] );

    # they should also strip leading slashes
    eq_or_diff( ['blah/foo.bar'], [ $model->raw_needed( 'include',   '/blah/foo.bar' ) ] );
    eq_or_diff( ['blah/foo.bar'], [ $model->raw_needed( 'use',       '/blah/foo.bar' ) ] );
    eq_or_diff( ['blah/foo.bar'], [ $model->raw_needed( 'invokefor', '/blah/foo.bar', 'append', '{}' ) ] );

    # 'invokefor' has a special 1-arg form that must be tokenized
    eq_or_diff( ['blah/foo.bar'], [ $model->raw_needed( 'invokefor', 'blah/foo.bar append {}' ) ] );

    # 2-level dependency resolution doesn't work for 'include' (otherwise it might be weird if {} is the filename)
    eq_or_diff( ['blah/foo.bar'], [ $model->raw_needed( 'invokefor', 'blah/foo.bar', 'include', '{}' ) ] );
    eq_or_diff( ['blah/foo.bar'], [ $model->raw_needed( 'invokefor', 'blah/foo.bar', 'include', 'xxx' ) ] );
}

# 2-level dependency resolution does work for 'add' and 'srsadd'
eq_or_diff( [ 'blah/foo.bar', 'passwd' ], [ $model_passwd->raw_needed( 'invokefor', 'blah/foo.bar', 'add', '{}' ) ] );
eq_or_diff( [ 'blah/foo.bar', 'passwd' ],
    [ $model_passwd->raw_needed( 'invokefor', 'blah/foo.bar', 'srsadd', '{}' ) ] );
eq_or_diff( [ 'blah/foo.bar', 'group' ], [ $model_group->raw_needed( 'invokefor', 'blah/foo.bar', 'add',    '{}' ) ] );
eq_or_diff( [ 'blah/foo.bar', 'group' ], [ $model_group->raw_needed( 'invokefor', 'blah/foo.bar', 'srsadd', '{}' ) ] );

# try an action that does not depend on raw files
eq_or_diff( [], [ $model_text->raw_needed( 'append', 'jack, jill' ) ] );
