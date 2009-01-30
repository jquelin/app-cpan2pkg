#
# This file is part of App::CPAN2Pkg.
# Copyright (c) 2009 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package App::CPAN2Pkg;

use strict;
use warnings;

use App::CPAN2Pkg::Module;
use POE;

our $VERSION = '0.1.0';

sub spawn {
    my ($class, $opts) = @_;

    my $session = POE::Session->create(
        inline_states => {
            # public events
            new_module  => \&new_module,
            package     => \&package,
            # poe inline states
            _start => \&_start,
            _stop  => sub { warn "stop"; },
        },
        args => $opts,
    );
    return $session->ID;
}



#--
# SUBS

#
# if ( not available in cooker )                is_in_dist
# then
#   compute dependencies                        find_prereqs
#   repeat with each dep
#   cpan2dist                                   cpan2dist
#   install local                               install_from_local
#   while ( not available locally )             is_installed
#   do
#       prompt user to fix manually
#   done
#   import                                      import_local_to_dist
#   submit                                              (included above)
#   ack available (manual?)
#
# else
#   urpmi --auto perl(module::to::install)       install_from_dist
# fi

# -- public events

sub new_module {
    my ($k, $module) = @_[KERNEL, ARG0];
    $k->post($module, 'is_in_dist');
}

sub package {
    my ($k, $module) = @_[KERNEL, ARG0];
    App::CPAN2Pkg::Module->spawn($module);
}


# -- poe inline states

sub _start {
    my ($k, $opts) = @_[KERNEL, ARG0];
    $k->alias_set('app');

    # start packaging some modules
    my $modules = $opts->{modules};
    $k->yield('package', $_) for @$modules;
}


1;
__END__

=head1 NAME

App::CPAN2Pkg - generating native linux packages from cpan



=head1 SYNOPSIS

    $ cpan2pkg
    $ cpan2pkg Module::Foo Module::Bar ...



=head1 DESCRIPTION

Don't use this module directly, refer to the C<cpan2pkg> script instead.

C<App::CPAN2Pkg> is the controller for the C<cpan2pkg> application. It
implements a POE session, responsible to schedule and advance module
packagement.

It is spawned by the poe session responsible for the user interface.



=head1 PUBLIC PACKAGE METHODS

=head2 my $id = App::CPAN2Pkg->spawn( \%params )

This method will create a POE session responsible for coordinating the
package(s) creation.

It will return the POE id of the session newly created.

You can tune the session by passing some arguments as a hash
reference, where the hash keys are:

=over 4

=item * modules => \@list_of_modules

A list of modules to start packaging.


=back



=head1 PUBLIC EVENTS ACCEPTED

The following events are the module's API.


=head2 package( $module )

Request the application to package (if needed) the perl C<$module>. Note
that the module can be either the top-most module of a distribution or
deep inside said distribution.



=head1 BUGS

Please report any bugs or feature requests to C<app-cpan2pkg at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-CPAN2Pkg>. I will
be notified, and then you'll automatically be notified of progress on
your bug as I make changes.



=head1 SEE ALSO

Our git repository is located at L<git://repo.or.cz/app-cpan2pkg.git>,
and can be browsed at L<http://repo.or.cz/w/app-cpan2pkg.git>.


You can also look for information on this module at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-CPAN2Pkg>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-CPAN2Pkg>

=item * Open bugs

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-CPAN2Pkg>

=back



=head1 AUTHOR

Jerome Quelin, C<< <jquelin@cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2009 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

