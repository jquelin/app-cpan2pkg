use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Utils;
# ABSTRACT: various utilities for cpan2pkg

use Exporter::Lite;
use File::ShareDir::PathClass qw{ dist_dir };
use FindBin                   qw{ $Bin };
use Path::Class;
 
our @EXPORT_OK = qw{ $SHAREDIR };

my $root = dir($Bin)->parent;
our $IS_DEVEL  = -e $root->file("dist.ini" );
our $SHAREDIR  = $IS_DEVEL ? $root->subdir("share") : dist_dir("App-CPAN2Pkg");

1;
__END__

=head1 DESCRIPTION

This module provides some helper variables and subs, to be used on
various occasions throughout the code.

