use 5.012;
use strict;
use warnings;

package App::CPAN2Pkg::Lock;
# ABSTRACT: Simple locking mechanism within cpan2pkg

use Moose;
use MooseX::Has::Sugar;

# -- attributes

=attr owner

The lock owner (a string).

=cut

has owner => (
    rw,
    isa       => 'Str',
    writer    => '_set_owner',
    clearer   => '_clear_owner',
    predicate => '_has_owner',
);


# -- methods

=method is_available

    $lock->is_available;

Return true if one can get control on C<$lock>.

=cut

sub is_available {
    my $self = shift;
    return ! $self->_has_owner;
}


=method get

    $lock->get( $owner );

Try to give the C<$lock> control to C<$owner>. Dies if it's already
owned by something else, or if new C<$owner> is not specified.

=cut

sub get {
    my ($self, $owner) = @_;
    die "need to specify owner parameter" unless defined $owner;
    if ( $self->_has_owner ) {
        my $current = $self->owner;
        die "lock already owned by $current";
    }
    $self->_set_owner( $owner );
}


=method release

    $lock->release;

Release C<$lock>. It's now available for locking again.

=cut

sub release {
    my $self = shift;
    $self->_clear_owner;
}

1;
__END__

=head1 SYNOPSIS

    use App::CPAN2Pkg::Lock;
    my $lock = App::CPAN2Pkg::Lock->new;
    $lock->get( 'foo' );
    # ...
    $lock->is_available; # false
    $lock->owner;        # foo
    $lock->get( 'bar' ); # dies
    # ...
    $lock->release;


=head1 DESCRIPTION

This class implements a simple locking mechanism.
