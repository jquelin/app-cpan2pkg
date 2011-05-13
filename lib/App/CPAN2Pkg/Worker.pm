use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Worker;
# ABSTRACT: poe session to drive a module packaging

use List::MoreUtils qw{ firstidx };
use Moose;
use MooseX::ClassAttribute;
use MooseX::Has::Sugar;
use MooseX::POE;
use MooseX::SemiAffordanceAccessor;
use POE;
use POE::Wheel::Run;
use Readonly;

use App::CPAN2Pkg::Lock;

Readonly my $K => $poe_kernel;


# -- class attributes

=classattr cpanplus_init

A boolean to state whether CPANPLUS has been initialized with new index.

=classattr cpanplus_lock

A lock (L<App::CPAN2Pkg::Lock> object) to prevent more than one cpanplus
initialization at a time.

=cut

class_has cpanplus_init => (
    rw,
    traits  => ['Bool'],
    isa     => 'Bool',
    default => 0,
    handles => { cpanplus_init_done => "set" },
);
class_has cpanplus_lock => ( ro, isa=>'App::CPAN2Pkg::Lock', default=>sub{ App::CPAN2Pkg::Lock->new } );


# -- public attributes

=attr module

The name of the module to build / install / submit / whatever.

=cut

has module => ( ro, required, isa=>'App::CPAN2Pkg::Module' );


# -- private attributes

# the wheel used to run an external command. a given worker will only
# run one wheel at a time, so we don't need to multiplex them.
has _wheel => ( rw, isa=>'POE::Wheel', clearer=>'_clear_wheel' );

# the output of the command
has _output => (
    ro,
    default => "",
    traits  => ['String'],
    isa     => 'Str',
    handles => {
        _clear_output => 'clear',
        _add_output   => 'append',
    },
);

# the event to fire once run_command() has finished.
has _result_event => ( rw, isa=>'Str', clearer=>'_clear_result_event' );

# some events need to be postponed to do other stuff before
# (initialization, etc). _next_event allows to store the event to be
# fired afterwards.
has _next_event => ( rw, isa=>'Str' );

# current worker state
has _state => ( rw, isa=>'Str', clearer=>'_clear_state', predicate=>'_has_state' );


# -- initialization

sub START {
    my $self = shift;
    $K->alias_set( $self->module->name );
    $K->post( main => new_module => $self->module );
    $K->yield( 'check_upstream_availability' );
}


# -- cpan2pkg logic implementation

{

=event check_upstream_availability

    check_upstream_availability( )

Check if module is available in the distribution repositories.

=cut

    event check_upstream_availability => sub { };

    event _check_upstream_availability_result => sub {
        my ($self, $status) = @_[OBJECT, ARG0];
        my $module  = $self->module;
        my $modname = $module->name;

        my $upstream = $status == 0 ? 'available' : 'not available';
        $module->upstream->set_status( $upstream );
        $K->post( main => log_result => $modname => "$modname is $upstream upstream." );
        $K->post( main => module_state => $module );
        $self->yield( "is_installed_locally" );
    };
}

{

=event is_installed_locally

    is_installed_locally( )

Check if the module is installed locally.

=cut

    event is_installed_locally => sub {
        my $self    = shift;
        my $modname = $self->module->name;

        my $cmd = qq{ perl -M$modname -E 'say "$modname loaded successfully";' };
        $K->post( main => log_step => $modname => "Checking if module is installed" );
        $self->run_command( $cmd => "_is_installed_locally_result" );
    };

    #
    # _is_installed_locally_result( $status )
    #
    # result of the command to check if the module is available locally.
    #
    event _is_installed_locally_result => sub {
        my ($self, $status) = @_[OBJECT, ARG0];
        my $module  = $self->module;
        my $modname = $module->name;

        my $local = $status == 0 ? 'available' : 'not available';
        $module->local->set_status( $local );
        $K->post( main => log_result => $modname => "$modname is $local locally." );
        $K->post( main => module_state => $module );

        # inform controller of availability
        $K->post( controller => module_ready_locally => $modname )
            if $local eq "available";

        if ( $module->upstream->status eq "available" ) {
            # nothing to do if available locally & upstream
            return if $module->local->status eq "available";

            # need to install the module from upstream
            $self->yield( "install_from_upstream" );

        } else {
            $self->yield( "cpanplus_find_prereqs" );
        }
    };
}

{

=event install_from_upstream

    install_from_upstream( )

Install module from distribution repository.

=cut

    event install_from_upstream => sub {
        my $self = shift;
        my $module  = $self->module;
        my $modname = $module->name;

        # change module state
        $module->local->set_status( 'installing' );
        $K->post( main => module_state => $module );
        $K->post( main => log_step => $modname => "Installing from upstream" );
    };

    #
    # _install_from_upstream_result( $status )
    #
    # Result of the command launched to install module from distribution
    # repository.
    #
    event _install_from_upstream_result => sub {
        my ($self, $status) = @_[OBJECT, ARG0];
        my $module  = $self->module;
        my $modname = $module->name;

        if ( $status == 0 ) {
            $module->local->set_status( 'available' );
            $K->post( main => log_result => $modname => "$modname is available locally." );

            # inform controller of availability
            $K->post( controller => module_ready_locally => $modname );
        } else {
            # error while installing
            $module->local->set_status( 'error' );
            $K->post( main => log_result => $modname => "$modname is not available locally." );
        }
        $K->post( main => module_state => $module );
    };
}

{

=event cpanplus_initialize

    cpanplus_initialize( $event )

Run CPANPLUS initialization (reload index, etc). Fire C<$event> when
finished, or if this has already been done. Wait 10 seconds before
retrying if initialization is currently ongoing.

=cut

    event cpanplus_initialize => sub {
        my ($self, $event) = @_[OBJECT, ARG0];
        $K->post( main => log_step => $self->module->name => "Initializing CPANPLUS" );
        $self->_set_next_event( $event );
        $self->yield( '_cpanplus_initialize_lock' );
    };

    #
    # _cpanplus_initialize_lock( )
    #
    # try to get a hand on cpanplus lock. once lock has been grabbed,
    # initialize cpanplus if needed. proceed to $self->_next_event
    # otherwise.
    #
    event _cpanplus_initialize_lock => sub {
        my $self = shift;
        my $modname = $self->module->name;
        my $lock    = $self->cpanplus_lock;

        # check whether there's another cpanplus initialization ongoing
        if ( ! $lock->is_available ) {
            my $owner   = $lock->owner;
            my $comment = "CPANPLUS currently being initialized... (cf $owner)";
            $K->post( main => log_comment => $modname => $comment );
            $K->delay( _cpanplus_initialize_lock => 10 );
            return;
        }

        # cpanplus lock available

        # check if cpanplus needs to be initialized
        if ( $self->cpanplus_init ) {
            $K->post( main => log_result => $modname => "CPANPLUS already initialized" );
            $self->yield( $self->_next_event );
            return;
        }

        # cpanplus not yet initialized
        $lock->get( $modname );
        my $cmd = "cpanp x --update_source";
        $self->run_command( $cmd => "_cpanplus_initialize_result" );
    };

    #
    # _cpanplus_initialize_result( $status )
    #
    # received when cpanplus initialization is finished. if init went
    # fine, proceed to $self->_next_event. otherwise, abort processing
    # and put current module in error.
    #
    event _cpanplus_initialize_result => sub {
        my ($self, $status) = @_[OBJECT, ARG0];
        my $module   = $self->module;
        my $modname  = $module->name;

        # release lock
        $self->cpanplus_lock->release;

        if ( $status == 0 ) {
            # cpanplus index reloaded, continue operations
            $self->cpanplus_init_done;
            $K->post( main => log_result => $modname => "CPANPLUS has been initialized" );
            $self->yield( $self->_next_event );
        } else {
            # cpanplus error, bail out for this module
            $module->local->set_status( "error" );
            $K->post( main => module_state => $module );
            $K->post( main => log_result => $modname => "CPANPLUS could not reload index, aborting" );
        }
    };
}

{

=event cpanplus_find_prereqs

    cpanplus_find_prereqs( )

Run CPANPLUS to find the module prereqs.

=cut

    event cpanplus_find_prereqs => sub {
        my $self = shift;
        $self->yield( cpanplus_initialize => "_cpanplus_find_prereqs_init_done" );
    };

    #
    # _cpanplus_find_prereqs_init_done( )
    #
    # run cpanplus to find module prereqs, now that cpanplus
    # initialization has been done.
    #
    event _cpanplus_find_prereqs_init_done => sub {
        my $self = shift;
        my $modname = $self->module->name;

        $K->post( main => log_step => $modname => "Finding module prereqs" );
        my $cmd = "cpanp /prereqs show $modname";
        $self->run_command( $cmd => "_cpanplus_find_prereqs_result" );
    };

    #
    # _cpanplus_find_prereqs_result( $status, $output )
    #
    # extract module prereqs from cpanplus output.
    #
    event _cpanplus_find_prereqs_result => sub {
        my ($self, $status, $output) = @_[ OBJECT, ARG0 .. $#_ ];
        my $modname = $self->module->name;

        # note that at this point, we still don't know if module exists
        # on cpan, since cpanplus unfortunately returns 0 even if there
        # was an error... sigh.

        # extract prereqs
        my @lines   = split /\n/, $output;
        my @tabbed  = grep { s/^\s+// } @lines;
        my $idx     = firstidx { /^Module\s+Req Ver.*Satisfied/ } @tabbed;
        my @wanted  = @tabbed[ $idx+1 .. $#tabbed ];
        my @prereqs = map { (split /\s+/, $_)[0] } @wanted;
        chomp( @prereqs );

        if ( @prereqs == 0 ) {
            # no prereqs found, build package!
            $K->post( main => log_result => $modname => "No prereq found." );
            $self->yield( "cpanplus_create_package" );
            return;
        }

        # store prereqs
        foreach my $p ( @prereqs ) {
            $K->post( main => log_result => $modname => "Prereq found: $p" );
            $self->module->add_prereq( $p );
            $K->post( controller => new_module_wanted => $p );
        }

        $self->yield( "local_prereqs_wait" );
    };
}

{

=event local_prereqs_wait

    local_prereqs_wait( )

Request to wait for local prereqs to be all present before attempting to
build the module locally.

=event local_prereqs_available

    local_prereqs_available( $modname )

Inform the worker that C<$modname> is now available locally. This may
unblock the worker from waiting if all the needed modules are present.

=cut

    event local_prereqs_wait => sub {
        my $self = shift;
        $self->_set_state( "local_prereqs_wait" );
        my $module  = $self->module;
        my $modname = $module->name;
        my @prereqs = sort $module->local->prereqs;
        $K->post( main => log_step => $modname => "Waiting for local prereqs" );
        $K->post( main => log_comment => $modname => "Missing prereqs: @prereqs" );
    };

    event local_prereqs_available => sub {
        my ($self, $newmod) = @_[OBJECT, ARG0];
        my $module  = $self->module;
        my $modname = $module->name;
        my $local   = $module->local;

        return unless $local->miss_prereq( $newmod );
        $local->rm_prereq( $newmod );
        return unless $self->_has_state && $self->_state eq "local_prereqs_wait";

        if ( $local->can_build ) {
            $self->_clear_state;
            $K->post( main => log_result => $modname => "All prereqs are available locally" );
            $self->yield( "cpanplus_create_package" );
            return;
        }

        my @prereqs = sort $module->local->prereqs;
        $K->post( main => log_comment => $modname => "Missing prereqs: @prereqs" );
    };

    event _local_prereqs_ready => sub {
        my $self = shift;
        my $module  = $self->module;
        my $modname = $module->name;
    };
}



# -- public methods

{

=method run_command

    $worker->run_command( $command, $event );

Run a C<$command> in another process, and takes care of everything.
Since it uses L<POE::Wheel::Run> underneath, it understands various
stuff such as running a code reference. Note: commands will be launched
under a C<C> locale.

Upon completion, yields back an C<$event> with the result status and the
command output.

=cut

    sub run_command {
        my ($self, $cmd, $event) = @_;

        $K->post( main => log_comment => $self->module->name => "Running: $cmd\n" );
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
        $self->_clear_output;
        $self->_set_result_event( $event );
        #print( "Child pid ", $child->PID, " started as wheel ", $child->ID, ".\n" );
    }

    event _child_stdout => sub {
        my ($self, $line, $wid) = @_[OBJECT, ARG0, ARG1];
        $self->_add_output( "$line\n" );
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
        $K->post( main => log_out => $self->module->name => "" );
        $status //=0;
        $self->yield( $self->_result_event, $status, $self->_output );
        $self->_clear_result_event;
    };
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=for Pod::Coverage
    START

=head1 DESCRIPTION

C<App::CPAN2Pkg::Worker> implements a POE session driving the whole
packaging process of a given module. It has different subclasses, used
to match the diversity of Linux distributions.

It is spawned by C<App::CPAN2Pkg::Controller> and uses a
C<App::CPAN2Pkg::Module> object to track module information.


