use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Worker::Mageia;
# ABSTRACT: worker dedicated to Mageia distribution

use Moose;

extends 'App::CPAN2Pkg::Worker::RPM';


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
