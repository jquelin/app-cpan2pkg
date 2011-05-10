use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Worker::RPM;
# ABSTRACT: worker specialized in rpm distributions

use Moose;

extends 'App::CPAN2Pkg::Worker';

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
