use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Worker::Mageia;
# ABSTRACT: worker dedicated to Mageia distribution

use Moose;
use MooseX::POE;
use POE;
use Readonly;

Readonly my $K => $poe_kernel;

extends 'App::CPAN2Pkg::Worker::RPM';

event is_available_upstream => sub {
    my $self = shift;
    my $modname = $self->module->name;

    my $cmd = "urpmq --whatprovides 'perl($modname)'";
    $K->post( main => log_step => $modname => "Checking if module is packaged upstream");
    $self->run_command( $cmd => "_result_is_available_upstream" );
};

event install_from_upstream => sub {
    my ($self) = shift;
    my $module  = $self->module;
    my $modname = $module->name;
    my $rpmlock = $self->rpmlock;

    # change module state
    $module->set_local_status( 'installing' );
    $K->post( main => module_state => $module );

    # check whether there's another rpm transaction
    if ( ! $rpmlock->is_available ) {
        my $owner   = $rpmlock->owner;
        my $comment = "waiting for rpm lock... (owned by $owner)";
        $K->post( main => log_comment => $modname => $comment );
        $K->delay( install_from_upstream => 5 );
        return;
    }
    $rpmlock->get( $modname );

    # preparing & run command
    my $cmd = "sudo urpmi --auto 'perl($modname)'";
    $K->post( main => log_step => $modname => "Installing from upstream" );
    $self->run_command( $cmd => "_result_install_from_upstream" );
};


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
