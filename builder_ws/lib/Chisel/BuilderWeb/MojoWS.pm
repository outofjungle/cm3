######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::BuilderWeb::MojoWS;

use strict;
use base 'Mojolicious';

use Log::Log4perl qw/:easy/;
use Chisel::BuilderWeb::MojoWS::Host;

sub startup {
    my ( $self ) = @_;

    # my $self = shift;
    # # load a configuration file for our app
    # my $config = $self->plugin( 'json_config', { file => $self->home->rel_file( 'fe.conf' ) } );
    # 
    # # secret for signing cookies (and to supress warnings in the logs)
    # # It's not clear if we need this but we can probably use keydb here
    # $self->secret( $config->{'pop_secret'} );

    Log::Log4perl->easy_init($TRACE);

    INFO "Application startup";

    $self->renderer->root( '/share/mojo/ws/templates' );
    $self->routes->route( '/host/(.hostname)/describe' )->via( 'GET' )->to( 'host#describe' );
    $self->routes->route( '/host/(.hostname)/workers' )->via( 'GET' )->to( 'host#workers' );

    return;
}

1;
