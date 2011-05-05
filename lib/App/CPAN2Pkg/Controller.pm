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


# -- public attributes

=attr queue

A list of modules to be build, to be specified during object creation.

=attr worker

The type of worker to use, eg C<App::CPAN2Pkg::Worker::Mageia>.

=cut

has queue  => ( ro, auto_deref, isa =>'ArrayRef[Str]' );
has worker => ( ro, required, isa=>'Str' );



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


