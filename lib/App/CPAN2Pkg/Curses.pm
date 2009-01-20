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
use Curses;
use Curses::UI::POE;
use POE;

use base qw{ Curses::UI::POE };


#--
# CONSTRUCTOR

sub spawn {
    my ($class, $opts) = @_;

    my $cui = $class->new(
        -color_support => 1,
        -userdata      => $opts,
        inline_states  => {
            # inline states
            _start => \&_start,
            _stop  => sub { warn "_stop"; },
        },
    );
    return $cui;
}


#--
# SUBS

#-- poe inline states

sub _start {
    my ($k, $self) = @_[KERNEL, HEAP];

    $k->alias_set('ui');
    $self->_build_gui;

    my $opts = $self->userdata;
    App::CPAN2Pkg->spawn($opts);
}

#



=pod


CPAN2Mdv - generating mandriva rpms from cpan

- Packages queue ------------------------------------------
Language::Befunge [ok]
    Test::Exception [ok]
        Test::Harness [ok]
            File::Spec [ok]
                Scalar::Util [ok]
                Carp [ok]
                Module::Build [ok]
                    Test::More [ok]
                ExtUtils::CBuilder [ok]
        Sub::Uplevel [ok]
    Storable [ok]
    aliased [ok]
    Readonly [ok]
    Class::XSAccessor [ok]
        AutoXS::Header [ok]
    Math::BaseCalc [ok]
    UNIVERSAL::require [ok]

enter = jump to, n = new, d = delete

=cut

#--
# METHODS

# -- private methods

sub _build_gui {
    my ($self) = @_;

    $self->_build_title;
    $self->_build_notebook;
    $self->_build_queue;
    $self->_set_bindings;
}

sub _build_title {
    my ($self) = @_;
    my $title = 'cpan2pkg - generating native linux packages from cpan';
    my $tb = $self->add(undef, 'Window', -height => 1);
    $tb->add(undef, 'Label', -bold=>1, -text=>$title);
}

sub _build_notebook {
    my ($self) = @_;

    my ($rows, $cols);
    getmaxyx($rows, $cols);
    my $mw = $self->add(undef, 'Window',
        '-y'    => 2,
        -height => $rows - 3,
    );
    my $nb = $mw->add(undef, 'Notebook');
    $self->{nb} = $nb;
}

sub _build_queue {
    my ($self) = @_;
    my $pane = $self->{nb}->add_page('Package queue');
    my $list = $pane->add(undef, 'Listbox');
}

sub _set_bindings {
    my ($self) = @_;
    $self->set_binding( sub{ die; }, "\cQ" );
}



1;
__END__
