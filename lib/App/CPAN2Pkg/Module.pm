#
# This file is part of App::CPAN2Pkg.
# Copyright (c) 2009 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package App::CPAN2Pkg::Module;

use 5.010;
use strict;
use warnings;

use Class::XSAccessor
    constructor => '_new',
    accessors   => {
        name      => 'name',
        _output    => '_output',
        _prereqs   => '_prereqs',
        _wheel     => '_wheel',
    };
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
# CONSTRUCTOR

sub spawn {
    my ($class, $module) = @_;

    # creating the object
    my $obj = App::CPAN2Pkg::Module->_new(
        name      => $module,
        _prereqs  => {},
        _wheel    => undef,
    );

    # spawning the session
    my $session = POE::Session->create(
        inline_states => {
            # public events
            cpan2dist         => \&cpan2dist,
            find_prereqs      => \&find_prereqs,
            install_from_dist => \&install_from_dist,
            is_in_dist        => \&is_in_dist,
            is_installed      => \&is_installed,
            # private events
            _cpan2dist         => \&_cpan2dist,
            _find_prereqs      => \&_find_prereqs,
            _install_from_dist => \&_install_from_dist,
            _is_in_dist        => \&_is_in_dist,
            _stderr            => \&_stderr,
            _stdout            => \&_stdout,
            # poe inline states
            _start => \&_start,
            #_stop  => sub { warn "stop " . $_[HEAP]->name . "\n"; },
        },
        heap => $obj,
    );
    return $session->ID;
}


#--
# SUBS

# -- public events

sub cpan2dist {
    my ($k, $self) = @_[KERNEL, HEAP];

    # preparing command
    my $name = $self->name;
    my $cmd = "cpan2dist --force --format=CPANPLUS::Dist::Mdv $name";
    $self->_log_new_step('Building package', "Running command: $cmd" );

    # running command
    $self->_output('');
    $ENV{LC_ALL} = 'C';
    my $wheel = POE::Wheel::Run->new(
        Program      => $cmd,
        CloseEvent   => '_cpan2dist',
        StdoutEvent  => '_stdout',
        StderrEvent  => '_stderr',
        StdoutFilter => POE::Filter::Line->new,
        StderrFilter => POE::Filter::Line->new,
    );

    # need to store the wheel, otherwise the process goes woo!
    $self->_wheel($wheel);
}

sub find_prereqs {
    my ($k, $self) = @_[KERNEL, HEAP];

    # preparing command
    my $module = $self->name;
    my $cmd = "cpanp /prereqs show $module";
    $self->_log_new_step('Finding module prereqs', "Running command: $cmd" );

    # running command
    $self->_output('');
    $ENV{LC_ALL} = 'C';
    my $wheel = POE::Wheel::Run->new(
        Program      => $cmd,
        CloseEvent   => '_find_prereqs',
        StdoutEvent  => '_stdout',
        StderrEvent  => '_stderr',
        StdoutFilter => POE::Filter::Line->new,
        StderrFilter => POE::Filter::Line->new,
    );

    # need to store the wheel, otherwise the process goes woo!
    $self->_wheel($wheel);
}

sub install_from_dist {
    my ($k, $self) = @_[KERNEL, HEAP];
    my $name = $self->name;

    # check whether there's another rpm transaction
    if ( $rpm_locked ) {
        $self->_log_prefixed_lines("waiting for rpm lock... (owned by $rpm_locked)");
        $k->delay( install_from_dist => 1 );
        return;
    }
    $rpm_locked = $name;

    # preparing command
    my $cmd  = "sudo urpmi --auto 'perl($name)'";
    $self->_log_new_step('Installing from upstream', "Running command: $cmd" );

    # running command
    $self->_output('');
    $ENV{LC_ALL} = 'C';
    my $wheel = POE::Wheel::Run->new(
        Program      => $cmd,
        StdoutEvent  => '_stdout',
        StderrEvent  => '_stderr',
        Conduit      => 'pty-pipe', # urpmi wants a pty
        StdoutFilter => POE::Filter::Line->new,
        StderrFilter => POE::Filter::Line->new,
    );
    $k->sig( CHLD => '_install_from_dist' );

    # need to store the wheel, otherwise the process goes woo!
    $self->_wheel($wheel);
}

sub is_in_dist {
    my ($k, $self) = @_[KERNEL, HEAP];

    # preparing command
    my $name = $self->name;
    my $cmd  = "urpmq --whatprovides 'perl($name)'";
    $self->_log_new_step('Checking if packaged upstream', "Running command: $cmd" );

    # running command
    $self->_output('');
    $ENV{LC_ALL} = 'C';
    my $wheel = POE::Wheel::Run->new(
        Program      => $cmd,
        #CloseEvent   => '_is_in_dist', # FIXME: cf rt#42757
        StdoutEvent  => '_stdout',
        StderrEvent  => '_stderr',
        Conduit      => 'pty-pipe', # urpmq wants a pty
        StdoutFilter => POE::Filter::Line->new,
        StderrFilter => POE::Filter::Line->new,
    );
    $k->sig( CHLD => '_is_in_dist' );

    # need to store the wheel, otherwise the process goes woo!
    $self->_wheel($wheel);
}


sub is_installed {
    my ($k, $self) = @_[KERNEL, HEAP];

    my $name = $self->name;
    my $cmd  = qq{ require $name };
    $self->_log_new_step(
        'Checking if module is installed',
        "Evaluating command: $cmd"
    );

    eval $cmd;
    my $what = $@ || "$name loaded successfully\n";
    $k->post('ui', 'append', $self, $what);

    my $is_installed = $@ eq '';
    my $status = $is_installed ? 'installed' : 'not installed';
    $self->_log_result("$name is $status locally.");
    $k->post('app', 'local_status', $self, $is_installed);
}

# -- private events

sub _cpan2dist {
    my ($k, $self, $id) = @_[KERNEL, HEAP, ARG0];
    my $name = $self->name;

    # terminate wheel
    my $wheel  = $self->_wheel;
    $self->_wheel(undef);

    my $output = $self->_output;
    my ($rpm, $srpm);
    $rpm  = $1 if $output =~ /rpm created successfully: (.*\.rpm)/;
    $srpm = $1 if $output =~ /srpm available: (.*\.src.rpm)/;

    if ( $rpm && $srpm ) {
        $self->_log_result(
            "$name has been successfully built",
            "srpm created: $srpm",
            "rpm created:  $rpm",
        );
        $k->post('app', 'cpan2dist', $self, 1);
    } else {
        $self->_log_result("error while building $name");
        $k->post('app', 'cpan2dist', $self, 0);
    }
}

sub _find_prereqs {
    my ($k, $self, $id) = @_[KERNEL, HEAP, ARG0];

    # terminate wheel
    my $wheel  = $self->_wheel;
    $self->_wheel(undef);

    # extract prereqs
    my @lines =
        grep { s/^\s+// }
        split /\n/, $self->_output;
    shift @lines; # remove the title line
    my @prereqs =
        map  { (split /\s+/, $_)[0] }
        @lines;

    # store prereqs
    my @logs = @prereqs
        ? map { "prereq found: $_" } @prereqs
        : 'No prereqs found.';
    $self->_log_result(@logs);
    $k->post('app', 'prereqs', $self, @prereqs);
}

sub _install_from_dist {
    my($k, $self, $pid, $rv) = @_[KERNEL, HEAP, ARG1, ARG2];

    # since it's a sigchld handler, it also gets called for other
    # spawned processes. therefore, screen out processes that are
    # not related to this object.
    return unless defined $self->_wheel;
    return unless $self->_wheel->PID == $pid;

    # terminate wheel
    $self->_wheel(undef);

    # release rpm lock
    $rpm_locked = '';

    # log result
    my $name  = $self->name;
    my $exval = $rv >> 8;
    my $status = $exval ? 'not been' : 'been';
    $self->_log_result( "$name has $status installed from upstream." );
    $k->post('app', 'upstream_install', $self, !$exval);
}

sub _is_in_dist {
    my($k, $self, $pid, $rv) = @_[KERNEL, HEAP, ARG1, ARG2];

    # since it's a sigchld handler, it also gets called for other
    # spawned processes. therefore, screen out processes that are
    # not related to this object.
    return unless defined $self->_wheel;
    return unless $self->_wheel->PID == $pid;

    # terminate wheel
    # FIXME: should be done in CloseEvent
    $self->_wheel(undef);

    # check if we got a hit
    # urpmq returns 0 if found, 1 otherwise.
    my $name  = $self->name;
    my $exval = $rv >> 8;

    my $status = $exval ? 'not' : 'already';
    $self->_log_result( "$name is $status packaged upstream." );
    $k->post('app', 'upstream_status', $self, !$exval);
}

sub _stderr {
    my ($k, $self, $line) = @_[KERNEL, HEAP, ARG0];
    $k->post('ui', 'append', $self, "stderr: $line\n");
}

sub _stdout {
    my ($k, $self, $line) = @_[KERNEL, HEAP, ARG0];
    $line .= "\n";
    $self->_output( $self->_output . $line );
    $k->post('ui', 'append', $self, "stdout: $line");
}


# -- poe inline states

sub _start {
    my ($k, $self) = @_[KERNEL, HEAP];

    $k->alias_set($self);
    $k->post('ui',  'module_spawned', $self);
    $k->post('app', 'module_spawned', $self);
}


#--
# METHODS

# -- private methods

sub _log_empty_line {
    my ($self, $nb) = @_;
    $nb //= 1; #/ FIXME padre syntaxic color glitch
    POE::Kernel->post('ui', 'append', $self, "\n" x $nb);
}

sub _log_prefixed_lines {
    my ($self, @lines) = @_;

    my $prefix = '*';
    POE::Kernel->post('ui', 'append', $self, $_)
        for map { "$prefix $_\n" } @lines;
}

sub _log_new_step {
    my ($self, $step, $comment) = @_;

    $self->_log_prefixed_lines('-' x 10, $step, '', $comment, '');
    $self->_log_empty_line;
}

sub _log_result {
    my ($self, @lines) = @_;

    $self->_log_empty_line;
    $self->_log_prefixed_lines( '', @lines, '', '' );
}


1;
__END__


=head1 NAME

App::CPAN2Pkg::Module - poe session to drive a module packaging



=head1 DESCRIPTION

C<App::CPAN2Pkg::Module> implements a POE session driving the whole
packaging process of a given module.

It is spawned by C<App::CPAN2Pkg> and implements the logic related to
the module availability in the distribution.



=head1 PUBLIC PACKAGE METHODS

=head2 my $id = App::CPAN2Pkg::Module->spawn( $module )

This method will create a POE session responsible for packaging &
installing the wanted C<$module>.

It will return the POE id of the session newly created.



=head1 PUBLIC EVENTS ACCEPTED

=head2 cpan2dist()

Build a native package for this module, using C<cpan2dist> with the C<--force> flag.


=head2 find_prereqs()

Start looking for any other module needed by current module.


=head2 install_from_dist()

Try to install module from upstream distribution.


=head2 is_in_dist()

Check whether the package is provided by an existing upstream package.


=head2 is_installed()

Check whether the package is installed locally.


=head1 METHODS

This package is also a class, used B<internally> to store private data
needed for the packaging stuff. The following accessors are therefore
available, but should not be used directly:

=over 4

=item name() - the module name

=back



=head1 SEE ALSO

For all related information (bug reporting, source code repository,
etc.), refer to C<App::CPAN2Pkg>'s pod, section C<SEE ALSO>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin@cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2009 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

