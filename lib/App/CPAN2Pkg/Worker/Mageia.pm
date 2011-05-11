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

    my $cmd  = "urpmq --whatprovides 'perl($modname)'";
    my $step    = "Checking if module is packaged upstream";
    my $comment = "Running: $cmd";
    $K->post( main => log_step => $modname => $step => $comment );
    $self->run_command( $cmd => "_result_is_available_upstream" );
};


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
