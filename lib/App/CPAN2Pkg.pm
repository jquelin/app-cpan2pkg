#
# This file is part of App::CPAN2Pkg.
# Copyright (c) 2009 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package App::CPAN2Pkg;

use warnings;
use strict;

use POE;

our $VERSION = '0.0.1';

sub spawn {
    my ($class, $opts) = @_;

    my $session = POE::Session->create(
        inline_states => {
            _start => \&_start,
            _stop  => sub { warn "stop"; },
        },
        args => $opts,
    );
    return $session->ID;
}


#
# status:
#  - computing dependencies
#  - installing dependencies
#  - check cooker availability
#  - cpan2dist
#  - install local
#  - check local availability
#  - mdvsys import
#  - mdvsys submit
#  - wait for kenobi build
#

sub _start {
}

sub _stop {
}

__END__

=head1 NAME

App::CPAN2Pkg - The great new App::CPAN2Pkg!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use App::CPAN2Pkg;

    my $foo = App::CPAN2Pkg->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head2 function1

=cut

sub function1 {
}

=head2 function2

=cut

sub function2 {
}

=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-cpan2pkg at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-CPAN2Pkg>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::CPAN2Pkg


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-CPAN2Pkg>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-CPAN2Pkg>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-CPAN2Pkg>

=item * Search CPAN

L<http://search.cpan.org/dist/App-CPAN2Pkg>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of App::CPAN2Pkg
