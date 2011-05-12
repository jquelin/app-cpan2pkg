use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Worker::Mageia;
# ABSTRACT: worker dedicated to Mageia distribution

use Moose;
use MooseX::POE;
use POE;
use Readonly;

extends 'App::CPAN2Pkg::Worker::RPM';

Readonly my $K => $poe_kernel;


override is_available_upstream => sub {
    my $self = shift;
    my $modname = $self->module->name;

    my $cmd = "urpmq --whatprovides 'perl($modname)'";
    $K->post( main => log_step => $modname => "Checking if module is packaged upstream");
    $self->run_command( $cmd => "_result_is_available_upstream" );
};

{   # install_from_upstream
    override install_from_upstream => sub {
        super();
        $K->yield( get_rpm_lock => "_install_from_upstream_with_rpm_lock" );
    };

    event install_from_upstream_with_rpm_lock => sub {
        my $self = shift;
        my $module  = $self->module;
        my $modname = $module->name;

        # preparing & run command
        my $cmd = "sudo urpmi --auto 'perl($modname)'";
        $self->run_command( $cmd => "_install_from_upstream_result" );
    };

}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
