use 5.012;
use strict;
use warnings;

package App::CPAN2Pkg;
# ABSTRACT: generating native linux packages from cpan

use MooseX::Singleton;
use MooseX::Has::Sugar;
use POE;
use Readonly;

use App::CPAN2Pkg::Controller;
use App::CPAN2Pkg::UI::Text;
use App::CPAN2Pkg::UI::Tk;
use App::CPAN2Pkg::Utils      qw{ $LINUX_FLAVOUR $WORKER_TYPE };

# -- private attributes

# keep track of modules being processed.
has _modules => (
    ro,
    isa     => 'HashRef[App::CPAN2Pkg::Module]',
    traits  => ['Hash'],
    handles => {
        all_modules     => 'keys',
        seen_module     => 'exists',
        register_module => 'set',
        forget_module   => 'delete',
        module          => 'get',
        nb_modules      => 'count',
    }
);


# -- public methods

=method all_modules

    my @modules = $app->all_modules;

Return the list of all modules that have been / are being processed.

=method nb_modules

    my $nbmods = $app->nb_modules;

Return the number of modules being processed.

=method seen_module

    my $bool = $app->seen_module( $modname );

Return true if C<$modname> has already been seen. It can be either
finished processing, or still ongoing.

=method register_module

    $app->register_module( $modname, $module );

Store C<$module> as the L<App::CPAN2Pkg::Module> object tracking
C<$modname>.

=method forget_module

    $app->forget_module( $modname );

Forget C<$modname> and its associated L<App::CPAN2Pkg::Module> object.

=method

    my $module = $app->module( $modname );

Return the C<$module> object registered for C<$modname>.

=cut

# those methods above are provided by moose traits for free


=method run

    App::CPAN2Pkg->run( [ @modules ] );

Start the application, with an initial batch of C<@modules> to build.

=cut

sub run {
    my (undef, $opt, @modules) = @_;

    # check if the platform is supported
    eval "require $WORKER_TYPE";
    die "Platform $LINUX_FLAVOUR is not supported" if $@ =~ /^Can't locate/;
    die $@ if $@;

    # create the poe sessions
    App::CPAN2Pkg::Controller->new( queue=>\@modules );
    my $ui = $opt->{ui} eq "gui"
        ? "App::CPAN2Pkg::UI::Tk" : "App::CPAN2Pkg::UI::Text";
    $ui->new;

    # and let's start the fun!
    POE::Kernel->run;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 SYNOPSIS

    $ cpan2pkg
    $ cpan2pkg Module::Foo Module::Bar ...


=head1 DESCRIPTION

Don't use this module directly, refer to the C<cpan2pkg> script instead.

C<App::CPAN2Pkg> is the main entry point for the C<cpan2pkg> application. It
also provides some information about processed modules.


=head1 BUGS

Please report any bugs or feature requests to C<app-cpan2pkg at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-CPAN2Pkg>. I will
be notified, and then you'll automatically be notified of progress on
your bug as I make changes.



=head1 SEE ALSO

You can look for information on this module at:

=over 4

=item * Search CPAN

L<http://search.cpan.org/dist/App-CPAN2Pkg>

=item * See open / report bugs

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-CPAN2Pkg>

=item * Git repository

L<http://github.com/jquelin/app-cpan2pkg>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-CPAN2Pkg>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-CPAN2Pkg>

=back

