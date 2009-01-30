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
        _current  => '_current',
        _lb       => '_listbox',
        _listbox  => '_listbox',
        _panes    => '_panes',
        _viewers  => '_viewers',
        _win      => '_win',
        _opts     => '_opts',
    };
use Curses;
use Curses::UI::Common;
use Curses::UI::POE;
use POE;


#--
# CONSTRUCTOR

sub spawn {
    my ($class, $opts) = @_;

    # the userdata object
    my $self = $class->_new(
        _opts    => $opts,
        _panes   => {},
        _viewers => {},
    );

    # the curses::ui object
    my $cui  = Curses::UI::POE->new(
        -color_support => 1,
        -userdata      => $self,
        inline_states  => {
            # public events
            append           => \&append,
            module_available => \&module_available,
            module_spawned   => \&module_spawned,
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

    my $name   = $module->name;
    my $viewer = $self->_viewers->{$name};
    my $text   = $viewer->text;
    $text .= $line;
    $viewer->text($text);

    # forcing redraw if needed
    $viewer->draw if $self->_current eq $name;
}

sub module_spawned {
    my ($k, $cui, $module) = @_[KERNEL, HEAP, ARG0];
    my $self = $cui->userdata;

    my $name = $module->name;

    # updating list of modules
    my $lb = $self->_listbox;
    my $values = $lb->values;
    my $pos = scalar @$values;
    $lb->add_labels( { $module => "- $name" } );
    $lb->insert_at($pos, $module);
    $lb->draw;

    # adding a new pane
    my $win = $self->_win;
    my $pane = $win->add(undef, 'Window');

    my $label = $pane->add(
        undef, 'Label',
        -height => 1,
        -text   => $name,
    );
    my $viewer = $pane->add(
        undef, 'TextViewer',
        '-y'        => 2,
        -text       => '',
        -vscrollbar => 1,
    );

    #$self->_set_bindings($pane);
    #$self->_set_bindings($viewer);

    # storing the new ui elements
    $self->_panes->{$name} = $pane;
    $self->_viewers->{$name} = $viewer;

    # forcing redraw if needed
    if ( not defined $self->_current ) {
        $self->_current($name);
        $win->draw;
        $viewer->draw;
        $viewer->focus;
    }
}

sub module_available {
    my ($cui, $module) = @_[HEAP, ARG0];
    my $self = $cui->userdata;

    my $name = $module->name;
    my $lb = $self->_listbox;
    $lb->add_labels( { $module => "+ $name" } );
    $lb->draw;
}


# -- poe inline states

sub _start {
    my ($k, $cui) = @_[KERNEL, HEAP];
    my $self = $cui->userdata;

    $k->alias_set('ui');
    $self->_build_gui($cui);

    my $opts = $self->_opts;
    App::CPAN2Pkg->spawn($opts);
}



#--
# METHODS

# -- gui events

sub _focus_to_listbox {
    my ($self) = @_;

    my $lb = $self->_listbox;
    $lb->focus;
}

sub _focus_to_viewer {
    my ($self) = @_;

    #my $lb = $self->_listbox;
    $self->_win->focus;
}


sub _listbox_item_selected {
    my ($self) = @_;

    my $lb = $self->_listbox;
    my $labels = $lb->labels;
    my $name   = $labels->{ $lb->get_active_value };
    $self->_current($name);
    $self->_viewers->{$name}->focus;
}

# -- private methods

sub _build_gui {
    my ($self, $cui) = @_;

    $self->_build_title($cui);
    $self->_build_queue($cui);
    $self->_build_right_window($cui);
    $self->_set_bindings($cui);
}

sub _build_title {
    my ($self, $cui) = @_;
    my $title = 'cpan2pkg - generating native linux packages from cpan';
    my $tb = $cui->add(undef, 'Window', -height => 1);
    $tb->add(undef, 'Label', -bold=>1, -text=>$title);
}

sub _build_queue {
    my ($self, $cui) = @_;
    my $win = $cui->add(undef, 'Window',
        qw/ -y 2 -width 40 -vscrollbar 1 -border 1 /,
    );
    my $list = $win->add(
        undef, 'Listbox',
        -onchange => sub { $self->_listbox_item_selected },
    );
    $list->set_binding( sub {$self->_focus_to_viewer}, CUI_TAB );
    $self->_listbox($list);
}

sub _build_right_window {
    my ($self, $cui) = @_;
    my $win = $cui->add(undef, 'Window',
        qw/ -x 41 -y 2 -border 1 /,
    );
    $self->_win($win);
    #$self->_set_bindings($win);
}

sub _set_bindings {
    my ($self, $widget) = @_;
    $widget->set_binding( sub{ die; }, "\cQ" );
    $widget->set_binding( sub {$self->_focus_to_listbox}, KEY_F(2) );
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


=head2 module_available( $module )

Sent when C<$module> is available. Updating list of modules to reflect
this new status.


=head2 module_spawned( $module )

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

