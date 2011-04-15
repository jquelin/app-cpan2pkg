use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Utils;
# ABSTRACT: various utilities for cpan2pkg

use Exporter::Lite;
use File::ShareDir::PathClass qw{ dist_dir };
 
our @EXPORT_OK = qw{ $SHAREDIR };
our $SHAREDIR  = dist_dir("App-CPAN2Pkg");

1;
__END__

=head1 DESCRIPTION

This module provides some helper variables and subs, to be used on
various occasions throughout the code.

