use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Worker::RPM;
# ABSTRACT: worker specialized in rpm distributions

use Moose;
use MooseX::ClassAttribute;
use MooseX::Has::Sugar;
use MooseX::POE;
use Readonly;

use App::CPAN2Pkg::Lock;

extends 'App::CPAN2Pkg::Worker';

Readonly my $K => $poe_kernel;


# -- attributes

=classattr rpmlock

A lock (L<App::CPAN2Pkg::Lock> object) to prevent more than one rpm
installation at a time.

=cut

class_has rpmlock => ( ro, isa=>'App::CPAN2Pkg::Lock', default=>sub{ App::CPAN2Pkg::Lock->new } );



# -- methods

override _install_from_upstream_result => sub {
    my $self = shift;
    $self->rpmlock->release;
    super();
};

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
