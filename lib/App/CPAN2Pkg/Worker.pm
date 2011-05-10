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

has module => ( ro, required, isa=>'App::CPAN2Pkg::Module' );


# -- private attributes

# the wheel used to run an external command. a given worker will only
# run one wheel at a time, so we don't need to multiplex them.
has _wheel => ( rw, isa=>'POE::Wheel', clearer=>'_clear_wheel' );

# the event to fire once run_command() has finished.
has _result_event => ( rw, isa=>'Str', clearer=>'_clear_result_event' );


# -- initialization

sub START {
    my $self = shift;
    $K->alias_set( $self->module->name );
    $K->post( main => new_module => $self->module );
    $K->yield( 'is_available_upstream' );
}


# -- public events

event is_installed_locally => sub {
    my $self   = shift;
    my $module = $self->module;

    my $cmd  = qq{ perl -M$module -E 'say "$module loaded successfully";' };
    my $step    = "Checking if module is installed";
    my $comment = "Running: $cmd";
    $K->post( main => log_step => $module->name => $step => $comment );
    $self->run_command( $cmd );
};


# -- public methods

=method run_command

    $worker->run_command( $command, $event );

Run a C<$command> in another process, and takes care of everything.
Since it uses L<POE::Wheel::Run> underneath, it understands various
stuff such as running a code reference. Note: commands will be launched
under a C<C> locale.

Upon completion, yields back an C<$event> with the result status.

=cut

sub run_command {
    my ($self, $cmd, $event) = @_;

    $ENV{LC_ALL} = 'C';
    my $child = POE::Wheel::Run->new(
        Program     => $cmd,
        Conduit     => "pty-pipe",
        StdoutEvent => "_child_stdout",
        StderrEvent => "_child_stderr",
        CloseEvent  => "_child_close",
    );

    $K->sig_child( $child->PID, "_child_signal" );
    $self->_set_wheel( $child );
    $self->_set_result_event( $event );
    #print( "Child pid ", $child->PID, " started as wheel ", $child->ID, ".\n" );
}


# -- private events

event _child_stdout => sub {
    my ($self, $line, $wid) = @_[OBJECT, ARG0, ARG1];
    $K->post( main => log_out => $self->module->name => $line );
};

event _child_stderr => sub {
    my ($self, $line, $wid) = @_[OBJECT, ARG0, ARG1];
    $K->post( main => log_err => $self->module->name => $line );
};

event _child_close => sub {
    my ($self, $wid) = @_[OBJECT, ARG0];
    #say "child closed all pipes";
};

event _child_signal => sub {
    my ($self, $pid, $status) = @_[OBJECT, ARG1, ARG2];
    $status //=0;
    $self->yield( $self->_result_event, $status );
    $self->_clear_result_event;
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

