#
# This file is part of App::CPAN2Pkg.
# Copyright (c) 2009 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package App::CPAN2Pkg::Curses;

use strict;
use warnings;

use App::CPAN2Pkg;
use Class::XSAccessor
    constructor => '_new',
    accessors   => {
        _lb       => '_listbox',
        _listbox  => '_listbox',
        _nb       => '_notebook',
        _notebook => '_notebook',
        _opts     => '_opts',
    };
use Curses;
use Curses::UI::POE;
use POE;


#--
# CONSTRUCTOR

sub spawn {
    my ($class, $opts) = @_;

    # the userdata object
    my $self = $class->_new( _opts => $opts );

    # the curses::ui object
    my $cui  = Curses::UI::POE->new(
        -color_support => 1,
        -userdata      => $self,
        inline_states  => {
            # public events
            append     => \&append,
            new_module => \&new_module,
            # inline states
            _start => \&_start,
            _stop  => sub { warn "_stop"; },
        },
    );
    return $cui;
}


#--
# SUBS

# -- public events

sub append {
    my ($cui, $module, $line) = @_[HEAP, ARG0, ARG1];
    my $self = $cui->userdata;

    my $name = $module->name;
    my $tv = $self->{textviewers}->{$name};
    my $text = $tv->text;
    $text .= "$line\n";
    $tv->text($text);
    $tv->focus;
}

sub new_module {
    my ($k, $cui, $module) = @_[KERNEL, HEAP, ARG0];
    my $self = $cui->userdata;

    my $name = $module->name;
    # adding a notebook pane
    my $nb = $self->_notebook;
    my $pane = $nb->add_page($module->shortname);
    my $textviewer = $pane->add(
        undef, 'TextViewer',
        -text => '',
        -vscrollbar => 1,
    );
    $self->{textviewers}->{$name} = $textviewer;
    $nb->draw;
    
    #
    my $lb = $self->_listbox;
    my $values = $lb->values;
    my $pos = scalar @$values;
    $lb->add_labels( { $module => $module->name } );
    $lb->insert_at($pos, $module);
    $lb->draw;
    $lb->focus;
}

#-- poe inline states

sub _start {
    my ($k, $cui) = @_[KERNEL, HEAP];
    my $self = $cui->userdata;

    $k->alias_set('ui');
    $self->_build_gui($cui);

    my $opts = $self->_opts;
    App::CPAN2Pkg->spawn($opts);
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

sub _build_gui {
    my ($self, $cui) = @_;

    $self->_build_title($cui);
    $self->_build_notebook($cui);
    $self->_build_queue($cui);
    $self->_set_bindings($cui);
}

sub _build_title {
    my ($self, $cui) = @_;
    my $title = 'cpan2pkg - generating native linux packages from cpan';
    my $tb = $cui->add(undef, 'Window', -height => 1);
    $tb->add(undef, 'Label', -bold=>1, -text=>$title);
}

sub _build_notebook {
    my ($self, $cui) = @_;

    my ($rows, $cols);
    getmaxyx($rows, $cols);
    my $mw = $cui->add(undef, 'Window',
        '-y'    => 2,
        -height => $rows - 3,
    );
    my $nb = $mw->add(undef, 'Notebook');
    $self->_notebook($nb);
}

sub _build_queue {
    my ($self, $cui) = @_;
    my $pane = $self->_nb->add_page('Package queue');
    my $list = $pane->add(undef, 'Listbox');
    $self->_lb($list);
}

sub _set_bindings {
    my ($self, $cui) = @_;
    $cui->set_binding( sub{ die; }, "\cQ" );
}



1;
__END__


=head1 NAME

App::CPAN2Pkg::Curses - curses user interface for cpan2pkg



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

It will return a C<Curses::UI::POE> object.

You can tune the session by passing some arguments as a hash
reference, where the hash keys are:

=over 4

=item * modules => \@list_of_modules

A list of modules to start packaging.


=back



=head1 PUBLIC EVENTS ACCEPTED

The following events are the module's API.


=head2 append( $module, $line )

Update the specific part of the ui devoluted to C<$module> with an
additional C<$line>.


=head2 new_module( $module )

Sent when a new module has been requested to be packaged. The argment
C<$module> is a C<App::CPAN2Pkg::Module> object with all the needed
information.



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

