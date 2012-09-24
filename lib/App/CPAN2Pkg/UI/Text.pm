use 5.012;
use strict;
use warnings;

package App::CPAN2Pkg::UI::Text;
# ABSTRACT: text interface for cpan2pkg

use DateTime;
use List::Util qw{ first };
use Moose;
use MooseX::Has::Sugar;
use MooseX::POE;
use MooseX::SemiAffordanceAccessor;
use POE;
use Readonly;
use Term::ANSIColor qw{ :constants };

Readonly my $K  => $poe_kernel;


# -- attributes

# keep track of module outpus
has _outputs => ( ro, isa => 'HashRef', default=>sub {{}} );


# -- initialization

#
# START()
#
# called as poe session initialization.
#
sub START {
    my $self = shift;
#    $poe_kernel->alias_set('main');
    POE::Kernel->alias_set('main');
}


# -- public logging events

{

=event log_out

=event log_err

=event log_comment

=event log_result

=event log_step

    log_XXX( $module, $line )

Log a C<$line> of output / stderr / comment / result / step in
C<$module> tab.

=cut

    event log_out => sub {
        my ($self, $modname, $line) = @_[OBJECT, ARG0 .. $#_ ];
        $self->_outputs->{$modname} .= "$line\n";
    };
    event log_err => sub {
        my ($self, $modname, $line) = @_[OBJECT, ARG0 .. $#_ ];
        $self->_outputs->{$modname} .= "$line\n";
    };
    event log_comment => sub {
        my ($self, $module, $line) = @_[OBJECT, ARG0 .. $#_ ];
        my $timestamp = DateTime->now(time_zone=>"local")->hms;
        $line =~ s/\n$//;
        print "$timestamp [$module] $line\n";
    };
    event log_result => sub {
        my ($self, $module, $result) = @_[OBJECT, ARG0 .. $#_ ];
        my $timestamp = DateTime->now(time_zone=>"local")->hms;
        local $Term::ANSIColor::AUTORESET = 1;
        print BLUE "$timestamp [$module] => $result\n"; 
    };
    event log_step => sub {
        my ($self, $module, $step) = @_[OBJECT, ARG0 .. $#_ ];
        my $timestamp = DateTime->now(time_zone=>"local")->hms;
        local $Term::ANSIColor::AUTORESET = 1;
        print BOLD "$timestamp [$module] ** $step\n"; 
    };
}

=event module_state

    module_state( $module )

Sent from the controller when a module has changed status (either
local or upstream).

=cut

event module_state => sub {
    my ($self, $module) = @_[OBJECT, ARG0 .. $#_ ];
    my $modname = $module->name;

    if ( $module->local->status    eq "error" or
         $module->upstream->status eq "error" ) {
        local $Term::ANSIColor::AUTORESET = 1;
        my $timestamp = DateTime->now(time_zone=>"local")->hms;
        print RED "$timestamp [$modname] error encountered\n";
        print "$timestamp [$modname] output follows:\n";
        print $self->_outputs->{$modname};
        print RED "$timestamp [$modname] aborting\n";
    }

    $self->_outputs->{$modname} = "";
};

# -- public events

=event new_module

    new_module( $module )

Received from the controller when a new module needs to be investigated.
Said module will be followed by a L<App::CPAN2Pkg::Worker> session.

=cut

event new_module => sub {
    my ($self, $module) = @_[OBJECT, ARG0];
    my $modname = $module->name;
};


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=for Pod::Coverage
    START


=head1 DESCRIPTION

This class implements a text interface for cpan2pkg. It's basic and
doesn't allow any interaction, however it will track the various modules
being built, their status. No details will be printed, unless in case of
failure. Useful when you only have a shell at hand.
