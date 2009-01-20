#
# This file is part of App::CPAN2Pkg.
# Copyright (c) 2009 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package App::CPAN2Pkg::Module;

use strict;
use warnings;

use Class::XSAccessor
    constructor => 'new',
    accessors   => {
        name      => 'name',
        shortname => 'shortname',
    };
use POE;

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
#   yes | urpmi perl(module::to::install)       install_from_dist
# fi

# on debian / ubuntu
# $ apt-file find Audio/MPD.pm
# libaudio-mpd-perl: /usr/share/perl5/Audio/MPD.pm
# status:
# - find dist hosting module
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




#--
# CONSTRUCTOR

sub spawn {
    my ($class, $module) = @_;

    # creating the object
    my $short = $module;
    $short =~ s/::/:/g;
    $short =~ s/[[:lower:]]//g;
    my $obj = App::CPAN2Pkg::Module->new(
        name      => $module,
        shortname => $short,
    );

    # spawning the session
    my $session = POE::Session->create(
        inline_states => {
            # poe inline states
            _start => \&_start,
            _stop  => sub { warn "stop"; },
        },
        heap => $obj,
    );
    return $session->ID;
}


#--
# SUBS

#-- poe inline states

sub _start {
    my ($k, $self) = @_[KERNEL, HEAP];

    $k->alias_set($self);
    $k->post('ui',  'new_module', $self);
    $k->post('app', 'new_module', $self);
}

#


#    CPAN2Mdv - generating mandriva rpms from cpan
#
#    - Packages queue ------------------------------------------
#    Language::Befunge [ok]
#        Test::Exception [ok]
#            Test::Harness [ok]
#                File::Spec [ok]
#                    Scalar::Util [ok]
#                    Carp [ok]
#                    Module::Build [ok]
#                        Test::More [ok]
#                    ExtUtils::CBuilder [ok]
#            Sub::Uplevel [ok]
#        Storable [ok]
#        aliased [ok]
#        Readonly [ok]
#        Class::XSAccessor [ok]
#            AutoXS::Header [ok]
#        Math::BaseCalc [ok]
#        UNIVERSAL::require [ok]
#
#    enter = jump to, n = new, d = delete


#--
# METHODS

# -- private methods


1;
__END__


=head1 NAME

App::CPAN2Pkg::Module - curses user interface for cpan2pkg



=head1 DESCRIPTION

C<App::CPAN2Pkg::Curses> implements a POE session driving a curses
interface for C<cpan2pkg>.

It is spawned directly by C<cpan2pkg> (since C<Curses::UI::POE> is a bit
special regarding the event loop), and is responsible for launching the
application controller (see C<App::CPAN2Pkg>).



=head1 PUBLIC PACKAGE METHODS

=head2 my $cui = App::CPAN2Pkg->spawn( \%params )

This method will create a POE session responsible for creating the
curses UI and reacting to it.

It will return a C<App::CPAN2Pkg::Curses> object, which inherits from
C<Curses::UI::POE>.

You can tune the session by passing some arguments as a hash
reference, where the hash keys are:

=over 4

=item * modules => \@list_of_modules

A list of modules to start packaging.


=back



=head1 SEE ALSO

For all related information (bug reporting, source code repository,
etc.), refer to C<App::CPAN2Pkg>'s pod, section C<SEE ALSO>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin@cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2009 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

