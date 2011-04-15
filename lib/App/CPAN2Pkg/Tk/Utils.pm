use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Tk::Utils;
# ABSTRACT: Tk utilities for gui building

use Exporter::Lite;
use POE;

use App::CPAN2Pkg::Utils qw{ $SHAREDIR };

our @EXPORT = qw{ image };


# -- public subs

=method image

    my $img = image( $path [, $toplevel ] );

Return a tk image loaded from C<$path>. If the photo has already been
loaded, return a handle on it. If C<$toplevel> is given, it is used as
base window to load the image.

=cut

sub image {
    my ($path, $toplevel) = @_;
    $toplevel //= $poe_main_window;
    my $img = $poe_main_window->Photo($path);
    return $img if $img->width;
    return $toplevel->Photo("$toplevel-$path", -file=>$path);
}


1;
__END__


=head1 DESCRIPTION

This module exports some useful subs for tk guis.

