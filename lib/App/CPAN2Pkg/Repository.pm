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

=attr prereqs

The prerequesites needed before attempting to build the module.

=cut

has status  => ( rw, isa=>"Status", default=>"not started" );
has prereqs => (
    ro, auto_deref,
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        add_prereq => 'push',
    },
);


# -- public methods

=method add_prereq

    $status->add_prereq( $foo, $bar );

Mark a prereq as missing on the repository.

=cut

# provided by moose traits


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 DESCRIPTION

C<cpan2pkg> deals with two kinds of systems: the local system, and
upstream distribution repository. A module has some characteristics on
both systems (such as availability, etc). Those characteristics are
gathered in this module.

