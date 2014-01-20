use 5.012;
use warnings;
use strict;

package App::CPAN2Pkg::Types;
# ABSTRACT: types used in the distribution

use Moose::Util::TypeConstraints;

enum Status => [ "not started", "not available", qw{ importing building installing available error } ];

1;
__END__

=head1 DESCRIPTION

This module implements the specific types used by the distribution, and
exports them (exporting is done by L<Moose::Util::TypeConstraints>).

