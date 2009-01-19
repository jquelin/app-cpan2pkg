#
# This file is part of App::CPAN2Pkg.
# Copyright (c) 2009 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package App::CPAN2Pkg::Curses;

use App::CPAN2Pkg;
use Curses;
use Curses::UI::POE;
use POE;

use base qw{ Curses::UI::POE };


# debugging with curses is not easy
if ( exists $ENV{CPAN2PKG_DEBUG} ) {
    $SIG{__DIE__} = $SIG{__WARN__} = sub {
        open my $fh, '>>', 'stderr';
        print $fh @_;
    };
    warn '-' x 40 . "\n";
}

#--
# CONSTRUCTOR

sub spawn {
    my ($class, $opts) = @_;

    my $cui = $class->new(
        -color_support => 1,
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
    $self->_build_main_window;
    $self->_build_queue;
    $self->_set_bindings;
}

sub _build_title {
    my ($self) = @_;
    my $tb = $self->add(undef, 'Window', -height => 1);
    $self->{title} = $tb->add(undef, 'Label', -bold=>1);
}

sub _build_main_window {
    my ($self) = @_;

    my ($rows, $cols);
    getmaxyx($rows, $cols);
    my $mw = $self->add(undef, 'Window',
        -border => 1,
        '-y'    => 1,
        -height => $rows - 2,
    );
    $self->{mw} = $mw;
}

sub _build_queue {
    my ($self) = @_;
    my $list = $self->{mw}->add(undef, 'Listbox');
    $self->{listbox} = $list;
}

sub _set_bindings {
    my ($self) = @_;
    $self->set_binding( sub{ die; }, "\cQ" );
}



1;
__END__