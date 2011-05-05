use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Controller;
# ABSTRACT: controller for cpan2pkg interface

use Moose;
use MooseX::POE;
use Readonly;

Readonly my $K => $poe_kernel;

# -- initialization

#
# START()
#
# called as poe session initialization.
#
sub START {
    my $self = shift;
    $K->alias_set('controller');
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


