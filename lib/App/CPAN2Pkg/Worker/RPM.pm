use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Worker::RPM;
# ABSTRACT: worker specialized in rpm distributions

use Moose;
use MooseX::ClassAttribute;
use MooseX::Has::Sugar;
use MooseX::POE;
use Path::Class;
use Readonly;

use App::CPAN2Pkg::Lock;

extends 'App::CPAN2Pkg::Worker';

Readonly my $K => $poe_kernel;


# -- class attributes

=classattr rpmlock

A lock (L<App::CPAN2Pkg::Lock> object) to prevent more than one rpm
installation at a time.

=cut

class_has rpmlock => ( ro, isa=>'App::CPAN2Pkg::Lock', default=>sub{ App::CPAN2Pkg::Lock->new } );


# -- attributes

=attr srpm

Path to the source RPM of the module built with C<cpan2dist>.

=attr rpm

Path to the RPM of the module built with C<cpan2dist>.

=cut

has srpm => ( rw, isa=>'Path::Class::File' );
has rpm  => ( rw, isa=>'Path::Class::File' );


# -- cpan2pkg logic implementation

{   # _install_from_upstream_result
    override _install_from_upstream_result => sub {
        my $self = shift;
        $self->rpmlock->release;
        super();
    };
}

{   # _cpanplus_create_package_result
    override _cpanplus_create_package_result => sub {
        my ($self, $status, $output) = @_[OBJECT, ARG0 .. $#_ ];
        my $module  = $self->module;
        my $modname = $module->name;

        # check whether the package has been built correctly.
        my ($rpm, $srpm);
        $rpm  = $1 if $output =~ /rpm created successfully: (.*\.rpm)/;
        $srpm = $1 if $output =~ /srpm available: (.*\.src.rpm)/;

        # detecting error cannot be done on $status - sigh.
        if ( not ( $rpm && $srpm ) ) {
            $module->local->set_status( "error" );
            $K->post( main => module_state => $module );
            $K->post( main => log_result => $modname => "Error during package creation" );
            return;
        }

        # logging result
        $K->post( main => log_result => $modname => "Package built successfully" );
        $K->post( main => log_result => $modname => "SRPM: $srpm" );
        $K->post( main => log_result => $modname => "RPM:  $rpm" );

        # storing path to packages
        $self->set_srpm( file($srpm) );
        $self->set_rpm ( file($rpm) );

        $self->yield( "local_install_from_package" );
    };
}

{   # local_install_from_package
    override local_install_from_package => sub {
        super();
        $K->yield( get_rpm_lock => "_local_install_from_package_with_rpm_lock" );
    };

    event _local_install_from_package_with_rpm_lock => sub {
        my $self = shift;
        my $rpm = $self->rpm;
        my $cmd = "sudo rpm -Uv --force $rpm";
        $self->run_command( $cmd => "_local_install_from_package_result" );
    };

    override _local_install_from_package_result => sub {
        my $self = shift;
        $self->rpmlock->release;
        super();
    };
}


# -- events

=event get_rpm_lock

    get_rpm_lock( $event )

Try to get a hold on RPM lock. Fire C<$event> if lock was grabbed
successfully, otherwise wait 5 seconds before trying again.

=cut

event get_rpm_lock => sub {
    my ($self, $event) = @_[OBJECT, ARG0];
    my $module  = $self->module;
    my $modname = $module->name;
    my $rpmlock = $self->rpmlock;

    # check whether there's another rpm transaction
    if ( ! $rpmlock->is_available ) {
        my $owner   = $rpmlock->owner;
        my $comment = "waiting for rpm lock... (owned by $owner)";
        $K->post( main => log_comment => $modname => $comment );
        $K->delay( get_rpm_lock => 5, $event );
        return;
    }

    # rpm lock available, grab it
    $rpmlock->get( $modname );
    $self->yield( $event );
};


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 DESCRIPTION

This class implements a worker specific to RPM-based distributions. It
inherits from L<App::CPAN2Pkg::Worker>.

