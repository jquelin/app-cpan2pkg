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
    constructor => '_new',
    accessors   => {
        name      => 'name',
        shortname => 'shortname',
        _wheels    => '_wheels',
    };
use POE;
use POE::Filter::Line;
use POE::Wheel::Run;

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
    my $obj = App::CPAN2Pkg::Module->_new(
        name      => $module,
        shortname => $short,
        _wheels    => {},
    );

    # spawning the session
    my $session = POE::Session->create(
        inline_states => {
            # public events
            find_prereqs => \&find_prereqs,
            # private events
            _find_prereqs_end    => \&_find_prereqs_end,
            _find_prereqs_stderr => \&_find_prereqs_stderr,
            _find_prereqs_stdout => \&_find_prereqs_stdout,
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

# -- public events

sub find_prereqs {
    my ($k, $self) = @_[KERNEL, HEAP];

    # FIXME: update gui

    my $module = $self->name;
    my $cmd = "cpanp /prereqs show $module";
    my $wheel = POE::Wheel::Run->new(
        Program      => $cmd,
        CloseEvent   => '_find_prereqs_end',
        StdoutEvent  => '_find_prereqs_stdout',
        StderrEvent  => '_find_prereqs_stderr',
        #ErrorEvent   => '_find_prereqs_error',
        StdoutFilter => POE::Filter::Line->new,
        StderrFilter => POE::Filter::Line->new,
    );
    $wheel->shutdown_stdin;
    $self->_wheels->{ $wheel->ID } = $wheel;
    #$k->sig(CHLD => '_find_prereqs_reap');
}

# -- private events

sub _find_prereqs_end {
    warn "end!";
}

sub _find_prereqs_stderr {
    my ($k, $self, $line) = @_[KERNEL, HEAP, ARG0];
    $k->post('ui', 'append', $self, $line);
}

sub _find_prereqs_stdout {
    my ($k, $self, $line) = @_[KERNEL, HEAP, ARG0];

    $k->post('ui', 'append', $self, $line);
}


# -- poe inline states

sub _start {
    my ($k, $self) = @_[KERNEL, HEAP];

    $k->alias_set($self);
    $k->post('ui',  'new_module', $self);
    $k->post('app', 'new_module', $self);
    $k->yield('find_prereqs');
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

App::CPAN2Pkg::Module - poe session to drive a module packaging



=head1 DESCRIPTION

C<App::CPAN2Pkg::Module> implements a POE session driving the whole
packaging process of a given module.

It is spawned by C<App::CPAN2Pkg> and implements the logic related to
the module availability in the distribution.



=head1 PUBLIC PACKAGE METHODS

=head2 my $id = App::CPAN2Pkg::Module->spawn( $module )

This method will create a POE session responsible for packaging &
installing the wanted C<$module>.

It will return the POE id of the session newly created.



=head1 PUBLIC EVENTS ACCEPTED

=head2 find_prereqs()

Start looking for any other module needed by current module.



=head1 METHODS

This package is also a class, used B<internally> to store private data
needed for the packaging stuff. The following accessors are therefore
available, but should not be used directly:

=over 4

=item name() - the module name

=item shortname() - the module shortname (only capital letters)

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

