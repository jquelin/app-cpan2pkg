use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Controller;
# ABSTRACT: controller for cpan2pkg interface

use Moose;
use MooseX::Has::Sugar;
use MooseX::POE;
use MooseX::SemiAffordanceAccessor;
use Readonly;

use App::CPAN2Pkg;
use App::CPAN2Pkg::Module;
use App::CPAN2Pkg::Utils qw{ $WORKER_TYPE };

Readonly my $K => $poe_kernel;


# -- public attributes

=attr queue

A list of modules to be build, to be specified during object creation.

=cut

has queue       => ( ro, auto_deref, isa =>'ArrayRef[Str]' );



# -- initialization

#
# START()
#
# called as poe session initialization.
#
sub START {
    my $self = shift;
    $K->alias_set('controller');
    $self->yield( new_module_wanted => $_ ) for $self->queue;
}


# -- events

=event new_module_wanted

    new_module_wanted( $modname )

Request C<$modname> to be investigated. It can already exist in this
run, in which case it won't be propagated any further.

=cut

event new_module_wanted => sub {
    my ($self, $modname) = @_[OBJECT, ARG0];

    my $app = App::CPAN2Pkg->instance;
    if ( $app->seen_module( $modname ) ) {
        my $module = $app->module( $modname );
        my $sender = $_[SENDER];
        $K->post( $sender => local_prereqs_available => $modname )
            if $module->local->status eq "available";
        $K->post( $sender => upstream_prereqs_available => $modname )
            if $module->upstream->status eq "available";
        return;
    }

    my $module = App::CPAN2Pkg::Module->new( name => $modname );
    $app->register_module( $modname => $module );
    $WORKER_TYPE->new( module => $module );
};


=event module_ready_locally

    module_ready_locally( $modname )

Received when a worker has finished building / installing / fetching a
module locally, meaning it is available on this very platform.

=cut

event module_ready_locally => sub {
    my ($self, $modname) = @_[OBJECT, ARG0];
    my $app = App::CPAN2Pkg->instance;
    $K->post( $_ => local_prereqs_available => $modname )
        for $app->all_modules;
};


=event module_ready_upstream

    module_ready_upstream( $modname )

Received when a worker has witnessed a module is available upstream,
either because it existed previously, or because it has been built on
build system.

=cut

event module_ready_upstream => sub {
    my ($self, $modname) = @_[OBJECT, ARG0];
    my $app = App::CPAN2Pkg->instance;
    $K->post( $_ => upstream_prereqs_available => $modname )
        for $app->all_modules;
};

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=for Pod::Coverage
    START


=head1 DESCRIPTION

This module implements a POE session responsible for dispatching events
from and to the interface.

