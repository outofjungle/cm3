######################################################################
# Copyright (c) 2012, Yahoo! Inc. All rights reserved.
#
# This program is free software. You may copy or redistribute it under
# the same terms as Perl itself. Please see the LICENSE.Artistic file 
# included with this project for the terms of the Artistic License
# under which this project is licensed. 
######################################################################


package Chisel::BuilderWeb::MojoWS::Host;

use strict;
use base 'Mojolicious::Controller';

use YAML::XS ();
use Chisel::BuilderWeb::Singletons;
use Chisel::Workspace;

sub describe {
    my ( $self ) = @_;

    my $hostname = $self->stash( 'hostname' );
    my $engine   = Chisel::BuilderWeb::Singletons->engine;
    my $ws       = Chisel::BuilderWeb::Singletons->ws;

    my $bucket = $ws->host_bucket( $hostname );

    if( $bucket ) {
        my $manifest = $bucket->manifest( emit => ['blob'], include_dotfiles => 1 );
        my $error = $manifest->{'.error'} && $ws->cat_blob( $manifest->{'.error'}{'blob'} );
        $error = $engine->scrub_error( $error );

        my $version = $manifest->{'VERSION'} && $ws->cat_blob( $manifest->{'VERSION'}{'blob'} );

        my @transforms;
        if( $bucket && $manifest->{'.bucket/transforms-index'} ) {
            my @transforms_index = @{ YAML::XS::Load( $ws->cat_blob( $manifest->{'.bucket/transforms-index'}{'blob'} ) ) };
            for my $tname (@transforms_index) {
                my $tid = "$tname@" . $manifest->{".bucket/transforms/$tname"}{'blob'};
                my $t   = $self->_transform( $tid );

                if( $t->is_good ) {
                    my %rules_by_file = map { $_ => [ $t->rules( file => $_ ) ] } $t->files;
                    push @transforms,
                      {
                        name  => $tname,
                        data  => $t->yaml,
                        ok    => Mojo::JSON->true,
                        rules => \%rules_by_file,
                      };
                } else {
                    push @transforms,
                      {
                        name  => $tname,
                        data  => $t->yaml,
                        ok    => Mojo::JSON->false,
                        error => $engine->scrub_error( $t->error ),
                      };
                }
            }
        }

        $self->render(
            json => {
                host => {
                    hostname   => $hostname,
                    error      => $error,
                    version    => $version,
                    transforms => \@transforms,
                }
            }
        );
    } else {
        $self->render( json => { message => "we haven't heard of this host" }, status => 404 );
    }

    return;
}

# get ZK cluster info for this host
sub workers {
    my ( $self ) = @_;

    my $hostname = $self->stash( 'hostname' );

    my %zkworkers;
    Chisel::BuilderWeb::Singletons->with_zk(
        sub {
            my $zk = shift;

            %zkworkers =
              map { $_ => { primary => Mojo::JSON->false, assigned => Mojo::JSON->false,, available => Mojo::JSON->false, } }
              $zk->get_workers;

            $zkworkers{$_}{available} = Mojo::JSON->true for $zk->get_workers_for_host( $hostname );
            $zkworkers{$_}{assigned}  = Mojo::JSON->true for $zk->get_assignments_for_host( $hostname );

            if( my $primary_worker = $zk->get_worker_for_host( $hostname ) ) {
                $zkworkers{$primary_worker}{primary} = Mojo::JSON->true;
            }
        }
    );

    $self->render( json => { workers => \%zkworkers } );
}

# Load transform based on stash('transformid')
# Or if we can't, then render an error and return undef.
sub _transform {
    my ( $self, $transformid ) = @_;

    my $ws = Chisel::BuilderWeb::Singletons->ws;
    my $mc = Chisel::BuilderWeb::Singletons->memcache;

    my ( $tname, $tblob ) = ( $transformid =~ /^(.+)\@(.+)$/ );
    if( !$tname ) {
        $self->render( json => { message => "Not a valid transform ID" }, status => 404 );
        return;
    }

    if( my $t = $mc->get("transform$transformid") ) {
        return $t;
    } else {
        my $data = eval { $ws->cat_blob( $tblob ) };
        if( !defined $data ) {
            $self->render( json => { message => "Transform data not found" }, status => 404 );
            return;
        }

        my $t = Chisel::Transform->new(
            name        => $tname,
            yaml        => $data,
            module_conf => Chisel::BuilderWeb::Singletons->module_conf,
        );

        # Force loading. Should make the transform serializable.
        $t->is_good;

        $mc->set("transform$transformid", $t);
        return $t;
    }
}

1;
