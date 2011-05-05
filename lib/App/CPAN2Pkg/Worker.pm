use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Worker;
# ABSTRACT: poe session to drive a module packaging

use Moose;
use MooseX::Has::Sugar;
use MooseX::POE;
use MooseX::SemiAffordanceAccessor;
use POE;
use Readonly;

Readonly my $K => $poe_kernel;


# -- public attributes

has module => ( ro, required, isa=>'App::CPAN2Pkg::Module' );

# -- initialization

sub START {
    my $self = shift;
    $K->alias_set( $self->module->name );
}


#--
# CONSTRUCTOR

sub spawn {
    my ($class, $module) = @_;

    my @public = qw{
        available_on_bs
        build_upstream
        cpan2dist
        find_prereqs
        import_upstream
        install_from_dist
        install_from_local
        is_in_dist
        is_installed
    };
    my @private = qw{
        _build_upstream
        _cpan2dist
        _find_prereqs
        _import_upstream
        _install_from_dist
        _install_from_local
        _is_in_dist
        _stderr
        _stdout
    };
    
    # spawning the session
    my $session = POE::Session->create(
        heap => $module,
        inline_states => {
            _start => \&_start,
            #_stop  => sub { warn "stop " . $_[HEAP]->name . "\n"; },
        },
        object_states => [
            $module => [ @public, @private ],
        ],
    );
    return $session->ID;
}


# -- poe inline states

sub _start {
    my ($k, $module) = @_[KERNEL, HEAP];

    $k->alias_set($module);
    $k->alias_set($module->name);
    $k->post('ui',  'module_spawned', $module);
    $k->post('app', 'module_spawned', $module);
}



1;
__END__

=head1 DESCRIPTION

C<App::CPAN2Pkg::Worker> implements a POE session driving the whole
packaging process of a given module.

It is spawned by C<App::CPAN2Pkg> and uses a C<App::CPAN2Pkg::Module>
object to implement the logic related to the module availability in the
distribution.



=head1 PUBLIC PACKAGE METHODS

=head2 my $id = App::CPAN2Pkg::Module->spawn( $module )

This method will create a POE session responsible for packaging &
installing the wanted C<$module> (an C<App::CPAN2Pkg::Module> object).

It will return the POE id of the session newly created.


=cut

