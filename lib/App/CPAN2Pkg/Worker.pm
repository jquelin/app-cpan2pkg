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
use POE::Wheel::Run;
use Readonly;

Readonly my $K => $poe_kernel;


# -- public attributes

=attr module

The name of the module to build / install / submit / whatever.

=cut

has module => ( ro, required, isa=>'Str' );


# -- private attributes

# the wheel used to run an external command. a given worker will only
# run one wheel at a time, so we don't need to multiplex them.
has _wheel => ( rw, isa=>'POE::Wheel', clearer=>'_clear_wheel' );


# -- initialization

sub START {
    my $self = shift;
    $K->alias_set( $self->module );
    $K->post( main => new_module => $self->module );
}


# -- public methods

=method run_command

    $worker->run_command( $command );

Run a C<$command> in another process, and takes care of everything.
Since it uses L<POE::Wheel::Run> underneath, it understands various
stuff such as running a code reference. Note: commands will be launched
under a C<C> locale.

=cut

sub run_command {
    my ($self, $cmd) = @_;

    $ENV{LC_ALL} = 'C';
    my $child = POE::Wheel::Run->new(
        Program     => $cmd,
        Conduit     => "pty",
        StdoutEvent => "_child_stdout",
        StderrEvent => "_child_stderr",
        CloseEvent  => "_child_close",
    );

    $K->sig_child( $child->PID, "_child_signal" );
    $self->_set_wheel( $child );
    #print( "Child pid ", $child->PID, " started as wheel ", $child->ID, ".\n" );
}


# -- private events

event _child_stdout => sub {
    my ($self, $line, $wid) = @_[OBJECT, ARG0, ARG1];
    say scalar(localtime) . " - $wid - " . $self->_wheel->PID . " - $line";
};

event _child_stderr => sub {
    my ($self, $line, $wid) = @_[OBJECT, ARG0, ARG1];
    #say "stderr: $line";
};

event _child_close => sub {
    my ($self, $wid) = @_[OBJECT, ARG0];
    #say "child closed all pipes";
};

event _child_signal => sub {
    my ($self, $pid, $status) = @_[ARG1, ARG2];
    $status //=0;
    #say "child exited with status $status";
};

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



no Moose;
__PACKAGE__->meta->make_immutable;
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

