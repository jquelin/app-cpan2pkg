
package App::CPAN2Pkg::Curses;

use base qw{ Curses::UI::POE };

sub spawn {
    my ($class, %opts) = @_;

    #use Curses::UI::POE;
    #Curses::UI::POE->new(
    $class->new(
        -color_support => 1,
        inline_states  => {
            _start => \&_start,
            _stop  => \&_stop,
        },
    );
}

sub _start {
    warn $_[HEAP];    
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



sub _build_menu {
    my ($cui) = shift;

=pod

    my $mnu_module = [
        { -label => 'Package new...', -callback => sub { warn; } },
        { -label => 'Exit',           -callback => sub { warn; } },
    ];
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
    my $menus = [
        { -label => 'Module', -submenu => $mnu_module },

    ];
    my $menu = $cui->add( 
        'menu', 'Menubar',
        -menu => $menus
    );

=cut

}



1;
__END__