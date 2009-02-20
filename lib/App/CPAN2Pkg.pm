#
# This file is part of App::CPAN2Pkg.
# Copyright (c) 2009 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package App::CPAN2Pkg;

use strict;
use warnings;

use App::CPAN2Pkg::Module;
use Class::XSAccessor
    constructor => '_new',
    accessors   => {
        _module    => '_module',
        _prereq    => '_prereq',
    };
use POE;

our $VERSION = '0.5.0';

sub spawn {
    my ($class, $opts) = @_;

    # create the heap object
    my $obj = App::CPAN2Pkg->_new(
        _module   => {}, #      {name}=obj store the objects
        _prereq   => {}, # hoh: {a}{b}=1   mod a is a prereq of b
    );

    # create the main session
    my $session = POE::Session->create(
        inline_states => {
            # public events
            available_on_bs      => \&available_on_bs,
            cpan2dist_status     => \&cpan2dist_status,
            upstream_status      => \&upstream_status,
            local_install        => \&local_install,
            local_status         => \&local_status,
            module_spawned       => \&module_spawned,
            package              => \&package,
            prereqs              => \&prereqs,
            upstream_import      => \&upstream_import,
            upstream_install     => \&upstream_install,
            # poe inline states
            _start => \&_start,
            #_stop  => sub { warn "stop app\n"; },
        },
        args => $opts,
        heap => $obj,
    );
    return $session->ID;
}



#--
# SUBS

#
# if ( not available in cooker )                is_in_dist
# then
#   compute dependencies                        find_prereqs
#   repeat with each dep
#   cpan2dist                                   cpan2dist
#   install local                               install_from_local
#   while ( not available locally )             is_installed
#   do
#       prompt user to fix manually
#   done
#   import                                      import_local_to_dist
#   submit                                              (included above)
#   ack available (manual?)
#
# else
#   urpmi --auto perl(module::to::install)       install_from_dist
# fi

# -- public events

sub available_on_bs {
    # FIXME: start submitting upstream what depends on this
}


sub cpan2dist_status {
    my ($k, $h, $module, $status) = @_[KERNEL, HEAP, ARG0, ARG1];
    # FIXME: what if $status is false

    $k->post($module, 'install_from_local');
}


sub local_install {
    my ($k, $h, $module, $success) = @_[KERNEL, HEAP, ARG0, ARG1];

    if ( not $success ) {
        # module has not been installed locally.
        # FIXME: ask user
        return;
    }

    # module has been installed locally.
    $k->post('ui', 'module_available', $module);

    # module available: nothing depends on it anymore.
    my $name = $module->name;
    $module->is_local(1);
    my $depends = delete $h->_prereq->{$name};
    my @depends = keys %$depends;

    # update all modules that were depending on it
    foreach my $m ( @depends ) {
        # remove dependency on module
        my $mobj = $h->_module->{$m};
        $mobj->missing_del($name);
        my @missing = $mobj->missing_list;
        $k->post('ui', 'prereqs', $mobj, @missing);

        if ( scalar @missing == 0 ) {
            # huzzah! no more missing prereqs - let's create a
            # native package for it.
            $k->post($mobj, 'cpan2dist');
        }
    }

    $k->post($module, 'import_upstream');
}


sub local_status {
    my ($k, $h, $module, $is_installed) = @_[KERNEL, HEAP, ARG0, ARG1];

    if ( not $is_installed ) {
        # module is not installed locally, check if
        # it's available upstream.
        $k->post($module, 'is_in_dist');
        return;
    }

    # module is already installed locally.
    $k->post('ui', 'module_available', $module);
    $k->post('ui', 'prereqs', $module);

    # module available: nothing depends on it anymore.
    my $name = $module->name;
    $module->is_local(1);
    my $depends = delete $h->_prereq->{$name};
    my @depends = keys %$depends;

    # update all modules that were depending on it
    foreach my $m ( @depends ) {
        # remove dependency on module
        my $mobj = $h->_module->{$m};
        $mobj->missing_del($name);
        my @missing = $mobj->missing_list;
        $k->post('ui', 'prereqs', $mobj, @missing);

        if ( scalar @missing == 0 ) {
            # huzzah! no more missing prereqs - let's create a
            # native package for it.
            $k->post($mobj, 'cpan2dist');
        }
    }
}

sub module_spawned {
    my ($k, $h, $module) = @_[KERNEL, HEAP, ARG0];
    my $name = $module->name;
    $h->_module->{$name} = $module;
    $k->post($module, 'is_installed');
}

sub package {
    my ($k, $h, $module) = @_[KERNEL, HEAP, ARG0];
    App::CPAN2Pkg::Module->spawn($module);
}

sub prereqs {
    my ($k, $h, $module, @prereqs) = @_[KERNEL, HEAP, ARG0..$#_];

    my @missing;
    foreach my $m ( @prereqs ) {
        # check if module is new. in which case, let's treat it.
        $k->yield('package', $m) unless exists $h->_module->{$m};

        # store missing module.
        push @missing, $m unless
            exists $h->_module->{$m}
            && $h->_module->{$m}->is_local;
    }

    $k->post('ui', 'prereqs', $module, @missing);
    if ( @missing ) {
        # module misses some prereqs - wait for them.
        my $name = $module->name;
        $module->missing_add($_) for @missing;
        $h->_prereq->{$_}{$name}  = 1 for @missing;

    } else {
        # no prereqs, move on
        $k->post($module, 'cpan2dist');
        return;
    }
}

sub upstream_install {
    my ($k, $module, $success) = @_[KERNEL, ARG0, ARG1];
    #$h->_module->{$name}->is_local(1);
    #FIXME: update prereqs
}


sub upstream_import {
    my ($k, $module, $success) = @_[KERNEL, ARG0, ARG1];
    # FIXME: what if wrong
    # FIXME: don't submit if missing deps on bs
    $k->post($module, 'build_upstream');
}


sub upstream_status {
    my ($k, $module, $is_available) = @_[KERNEL, ARG0, ARG1];
    my $event = $is_available ? 'install_from_dist' : 'find_prereqs';
    $k->post($module, $event);
}


# -- poe inline states

sub _start {
    my ($k, $opts) = @_[KERNEL, ARG0];
    $k->alias_set('app');

    # start packaging some modules
    my $modules = $opts->{modules};
    $k->yield('package', $_) for @$modules;
}


1;
__END__

=head1 NAME

App::CPAN2Pkg - generating native linux packages from cpan



=head1 SYNOPSIS

    $ cpan2pkg
    $ cpan2pkg Module::Foo Module::Bar ...



=head1 DESCRIPTION

Don't use this module directly, refer to the C<cpan2pkg> script instead.

C<App::CPAN2Pkg> is the controller for the C<cpan2pkg> application. It
implements a POE session, responsible to schedule and advance module
packagement.

It is spawned by the poe session responsible for the user interface.



=head1 PUBLIC PACKAGE METHODS

=head2 my $id = App::CPAN2Pkg->spawn( \%params )

This method will create a POE session responsible for coordinating the
package(s) creation.

It will return the POE id of the session newly created.

You can tune the session by passing some arguments as a hash
reference, where the hash keys are:

=over 4

=item * modules => \@list_of_modules

A list of modules to start packaging.


=back



=head1 PUBLIC EVENTS ACCEPTED

The following events are the module's API.


=head2 available_on_bs()

Sent when module is available on upstream build system.


=head2 cpan2dist_status( $module, $success )

Sent when C<$module> has been C<cpan2dist>-ed, with C<$success> being true
if everything went fine.


=head2 local_install( $module, $success )

Sent when C<$module> has been installed locally, with C<$success> return value.


=head2 local_status( $module, $is_installed )

Sent when C<$module> knows whether it is installed locally (C<$is_installed>
set to true) or not.


=head2 module_spawned( $module )

Sent when C<$module> has been spawned successfully.


=head2 package( $module )

Request the application to package (if needed) the perl C<$module>. Note
that the module can be either the top-most module of a distribution or
deep inside said distribution.


=head2 prereqs( $module, @prereqs )

Inform main application that C<$module> needs some C<@prereqs> (possibly
empty).


=head2 upstream_import( $module, $success )

Sent when C<$module> package has been imported in upstream repository.


=head2 upstream_install( $module, $success )

Sent after trying to install C<$module> from upstream dist. Result is passed
along with C<$success>.


=head2 upstream_status( $module, $is_available )

Sent when C<$module> knows whether it is available upstream (C<$is_available>
set to true) or not.



=head1 BUGS

Please report any bugs or feature requests to C<app-cpan2pkg at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-CPAN2Pkg>. I will
be notified, and then you'll automatically be notified of progress on
your bug as I make changes.



=head1 SEE ALSO

Our git repository is located at L<git://repo.or.cz/app-cpan2pkg.git>,
and can be browsed at L<http://repo.or.cz/w/app-cpan2pkg.git>.


You can also look for information on this module at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-CPAN2Pkg>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-CPAN2Pkg>

=item * Open bugs

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-CPAN2Pkg>

=back



=head1 AUTHOR

Jerome Quelin, C<< <jquelin@cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2009 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

