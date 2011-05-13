use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Repository;
# ABSTRACT: repository details for a given module

use Moose;
use MooseX::Has::Sugar;
use MooseX::SemiAffordanceAccessor;

use App::CPAN2Pkg::Types;


# -- public attributes

=attr status

The status of the module: available, building, etc.

=cut

has status  => ( rw, isa=>"Status", default=>"not started" );
has _prereqs => (
    ro,
    traits  => ['Hash'],
    isa     => 'HashRef[Str]',
    default => sub { {} },
    handles => {
        _add_prereq => 'set',
        prereqs     => 'keys',
        rm_prereq   => 'delete',
        can_build   => 'is_empty',
        miss_prereq => 'exists',
    },
);


# -- public methods

=attr prereqs

    my @prereqs = $repo->prereqs;

The prerequesites needed before attempting to build the module.

=method can_build

    my $bool = $repo->can_build;

Return true if there are no more missing prereqs.

=method miss_prereq

    my $bool = $repo->miss_prereq( $modname );

Return true if C<$modname> is missing on the system.

=method rm_prereq

    $repo->rm_prereq( $modname );

Remove C<$modname> as a missing prereq on the repository.

=cut

# methods above provided for free by moose traits.

=method add_prereq

    $repo->add_prereq( $modname );

Mark a prereq as missing on the repository.

=cut

sub add_prereq {
    my ($self, $modname) = @_;
    $self->_add_prereq( $modname, $modname );
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 DESCRIPTION

C<cpan2pkg> deals with two kinds of systems: the local system, and
upstream distribution repository. A module has some characteristics on
both systems (such as availability, etc). Those characteristics are
gathered in this module.

