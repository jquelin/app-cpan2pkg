use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Controller;
# ABSTRACT: controller for cpan2pkg interface

use Moose;
use MooseX::Has::Sugar;
use MooseX::POE;
use MooseX::SemiAffordanceAccessor;
use Readonly;

Readonly my $K => $poe_kernel;


=attr queue

A list of modules to be build, to be specified during object creation.

=cut

has queue => ( ro, auto_deref, isa =>'ArrayRef[Str]' );

# -- initialization

#
# START()
#
# called as poe session initialization.
#
sub START {
    my $self = shift;
    $K->alias_set('controller');
    $self->yield( new_module_wanted => $_ ) for $self->queue;
}


# -- events

event new_module_wanted => sub {
    my ($self, $module) = @_[OBJECT, ARG0];
    say "wanted: $module";
};

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=for Pod::Coverage
    START


