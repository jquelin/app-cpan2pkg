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
use base qw{ Curses::UI::POE };

#--
# CONSTRUCTOR

sub spawn {
    my ($class, %opts) = @_;

    my $cui = $class->new(
        -color_support => 1,
        inline_states  => {
            _start => \&_start,
            _stop  => sub { warn "_stop"; },
        },
    );
    return $cui;
}

sub _start {
    warn "_start";
    my ($cui) = @_[HEAP];
    _build_gui($cui);
    #$_[HEAP]->dialog("Hello!");
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

n = new, d = delete, enter = jump to

=cut

my $title;
sub _build_gui {
    my ($self) = @_;
    my $tb  = $self->add('win_title', 'Window', -height=>1);
    $title  = $tb->add('title',  'Label', -bold=>1, -width=>40);
    $title->text("Building package from cpan");

    $self->set_binding( sub { $title->text("foo")->draw; die; }, KEY_ENTER );
}


sub _build_menu {
    my ($self) = shift;

    my $mnu_module = [
        { -label => 'Package new...', -callback => sub { warn; } },
        { -label => 'Exit',           -callback => sub { warn; } },
    ];

=pod

    my $mnu_config = [];
    my $mnu_windows = [
        { -label => 'Packages queue', -callback => sub { warn; } },
        { -label => 'Window list',    -callback => sub { warn; } },
    ];
    my $mnu_help = [
        { -label => "Help", -callback => sub { warn; } },
        { -label => "Help", -callback => sub { warn; } },
        { -label => "Help", -callback => sub { warn; } },
        { -label => "Help", -callback => sub { warn; } },
    ];
    F1 - help
    F2 - packages queue
    F3 - window list
    F4 - config (?)

=cut

    my $menus = [
        { -label => 'Module', -submenu => $mnu_module },

    ];
    my $menu = $self->add( 
        'menu', 'Menubar',
        -menu => $menus
    );

}



1;
__END__