use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Worker::RPM;
# ABSTRACT: worker specialized in rpm distributions

use Moose;
use MooseX::ClassAttribute;
use MooseX::Has::Sugar;

use App::CPAN2Pkg::Lock;

extends 'App::CPAN2Pkg::Worker';


# -- attributes

=attr rpmlock

A lock (L<App::CPAN2Pkg::Lock> object) to prevent more than one rpm
installation at a time. Note that this object is common to all workers.

=cut

class_has rpmlock => ( ro, isa=>'App::CPAN2Pkg::Lock', default=>sub{ App::CPAN2Pkg::Lock->new } );



# -- methods

override _result_install_from_upstream => sub {
    my $self = shift;
    $self->rpmlock->release;
    super();
};

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
