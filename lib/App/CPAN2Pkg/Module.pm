use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Module;
# ABSTRACT: poe session to drive a module packaging

use Moose;
use MooseX::Has::Sugar;
use MooseX::SemiAffordanceAccessor;

use App::CPAN2Pkg::Repository;
use App::CPAN2Pkg::Types;


# -- public attributes

=attr name

The name of the Perl module, eg C<App::CPAN2Pkg>.

=attr local

The L<App::CPAN2Pkg::Repository> for the local system.

=attr upstream

The L<App::CPAN2Pkg::Repository> for the upstream Linux distribution.

=attr prereqs

The modules listed as prerequesites for the module. Note that each
repository (local & upstream) keep in addition a list of prereqs that
are B<missing>. This list keeps the module prereqs, even after they have
been fulfilled on the repositories.

=cut

has name => ( ro, required, isa=>'Str' );
has local    => ( ro, isa=>"App::CPAN2Pkg::Repository", default=>sub{ App::CPAN2Pkg::Repository->new } );
has upstream => ( ro, isa=>"App::CPAN2Pkg::Repository", default=>sub{ App::CPAN2Pkg::Repository->new } );

has prereqs => (
    ro, auto_deref,
    isa     => 'ArrayRef[Str]',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        _add_prereq => 'push',
    },
);

# -- public methods

=method add_prereq

    $module->add_prereq( $modname );

Add a prerequesite to the module, also list it as missing on both local
& upstream repositories.

=cut

sub add_prereq {
    my ($self, $p) = @_;
    $self->_add_prereq($p);
    $self->local->add_prereq($p);
    $self->upstream->add_prereq($p);
}

# --

use Class::XSAccessor
    accessors   => {
        # public
        is_avail_on_bs => 'is_avail_on_bs',
        is_local       => 'is_local',  # if module is available locally
        _name__           => 'name',
        # private
        _blocking  => '_blocking',
        _missing   => '_missing',
        _output    => '_output',
        _pkgname   => '_pkgname',
        _rpm       => '_rpm',
        _srpm      => '_srpm',
        _wheel     => '_wheel',
    };
use File::Basename  qw{ basename };
use List::MoreUtils qw{ firstidx };
use POE;
use POE::Filter::Line;
use POE::Wheel::Run;

my $rpm_locked = '';   # only one rpm transaction at a time


# on debian / ubuntu
# $ apt-file find Audio/MPD.pm
# libaudio-mpd-perl: /usr/share/perl5/Audio/MPD.pm
# status:
# - find dist hosting module
#  - computing dependencies
#  - installing dependencies
#  - check cooker availability
#  - cpan2dist
#  - install local
#  - check local availability
#  - mdvsys import
#  - mdvsys submit
#  - wait for kenobi build
#

#--
# SUBS

# -- public events

sub available_on_bs {
    my ($k, $self) = @_[KERNEL, OBJECT];
    $self->is_avail_on_bs(1);
    $k->post('app', 'available_on_bs', $self);
}

sub build_upstream {
    my ($k, $self) = @_[KERNEL, OBJECT];

    # preparing command.
    my $name    = $self->name;
    my $pkgname = $self->_pkgname;
    my $cmd = "mdvsys submit $pkgname";
    $self->_log_new_step('Submitting package upstream', "Running command: $cmd" );

    # running command
    $self->_output('');
    $ENV{LC_ALL} = 'C';
    my $wheel = POE::Wheel::Run->new(
        Program      => $cmd,
        StdoutEvent  => '_stdout',
        StderrEvent  => '_stderr',
        StdoutFilter => POE::Filter::Line->new,
        StderrFilter => POE::Filter::Line->new,
    );
    $k->sig( CHLD => '_build_upstream' );

    # need to store the wheel, otherwise the process goes woo!
    $self->_wheel($wheel);
}

# -- private events

sub _build_upstream {
    my($k, $self, $pid, $rv) = @_[KERNEL, OBJECT, ARG1, ARG2];

    # since it's a sigchld handler, it also gets called for other
    # spawned processes. therefore, screen out processes that are
    # not related to this object.
    return unless defined $self->_wheel;
    return unless $self->_wheel->PID == $pid;

    # terminate wheel
    $self->_wheel(undef);

    # we don't have a real way to know when the build is finished,
    # and when the package is available upstream. therefore, we're going
    # to ask the user to signal when it's available...
    my $name = $self->name;
    $self->_log_result( "$name has been submitted upstream." );
    my $question = "type 'enter' when package is available on build system upstream";
    $k->post('ui', 'ask_user', $self, $question, 'available_on_bs');
}


sub _cpan2dist {
    my ($k, $self, $id) = @_[KERNEL, OBJECT, ARG0];
    my $name = $self->name;

    # terminate wheel
    my $wheel  = $self->_wheel;
    $self->_wheel(undef);

    # check whether the package has been built correctly.
    my $output = $self->_output;
    my ($rpm, $srpm);
    $rpm  = $1 if $output =~ /rpm created successfully: (.*\.rpm)/;
    $srpm = $1 if $output =~ /srpm available: (.*\.src.rpm)/;

    my ($status, @result);
    if ( $rpm && $srpm ) {
        $status = 1;
        @result = (
            "$name has been successfully built",
            "srpm created: $srpm",
            "rpm created:  $rpm",
        );

        # storing path to interesting files
        $self->_rpm($rpm);
        $self->_srpm($srpm);

        # storing package name
        my $pkgname = basename $srpm;
        $pkgname =~ s/-\d.*$//;
        $self->_pkgname( $pkgname );

    } else {
        $status = 0;
        @result = ( "error while building $name" );
    }

    # update main application
    $self->_log_result(@result);
    $k->post('app', 'cpan2dist_status', $self, $status);
}


1;
__END__

=head1 DESCRIPTION

C<App::CPAN2Pkg::Module> implements a POE session driving the whole
packaging process of a given module.

It is spawned by C<App::CPAN2Pkg> and implements the logic related to
the module availability in the distribution.



=head1 METHODS

This package is also a class, used B<internally> to store private data
needed for the packaging stuff.



=head2 Constructor

=over 4

=item my $module = App::CPAN2Pkg::Module->new(name=>$name)

=back



=head2 Accessors

The following accessors are available:

=over 4

=item is_avail_on_bs() - whether the module is available on build system

=item is_local() - whether the module is installed locally

=item name() - the module name

=item prereqs() - the module prereqs

=back



=head2 Public methods

=over 4

=item blocking_add( $module )

Add C<$module> to the list of modules that current object is blocking
from locally before trying to build
the object.


=item blocking_clear( $module )

Remove C<$module> from the list of modules missing locally. This means that
module has been built and installed by cpan2pkg.


=item blocking_list( )

Get the list of modules missing before trying to build the object.


=item missing_add( $module )

Add C<$module> to the list of modules missing locally before trying to build
the object.


=item missing_del( $module )

Remove C<$module> from the list of modules missing locally. This means that
module has been built and installed by cpan2pkg.


=item missing_list( )

Get the list of modules missing before trying to build the object.


=back




=head2 Public events accepted


=over 4

=item available_on_bs()

Sent when module is available on upstream build system.


=item build_upstream()

Submit package to be build on upstream build system.


=item cpan2dist()

Build a native package for this module, using C<cpan2dist> with the C<--force> flag.


=item find_prereqs()

Start looking for any other module needed by current module.


=item import_upstream()

Try to import module into upstream distribution.


=item install_from_dist()

Try to install module from upstream distribution.


=item install_from_local()

Try to install module from package freshly build.


=item is_in_dist()

Check whether the package is provided by an existing upstream package.


=item is_installed()

Check whether the package is installed locally.


=back


=cut

