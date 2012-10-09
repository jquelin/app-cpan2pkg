use 5.010;
use strict;
use warnings;

package App::CPAN2Pkg::Worker::Mageia;
# ABSTRACT: worker dedicated to Mageia distribution

use HTML::TreeBuilder;
use HTTP::Request;
use Moose;
use MooseX::ClassAttribute;
use MooseX::Has::Sugar;
use MooseX::POE;
use POE;
use POE::Component::Client::HTTP;
use Readonly;

extends 'App::CPAN2Pkg::Worker::RPM';

Readonly my $K => $poe_kernel;

# -- class attribute

class_has _ua => ( ro, isa=>'Str', builder=>"_build__ua" );

sub _build__ua {
    my $ua = "mageia-bswait";
    POE::Component::Client::HTTP->spawn( Alias => $ua );
    return $ua;
}


# -- public methods

override cpan2dist_flavour => sub { "CPANPLUS::Dist::Mageia" };


# -- cpan2pkg logic implementation

{   # check_upstream_availability
    override check_upstream_availability => sub {
        my $self = shift;
        my $modname = $self->module->name;

        my $cmd = "urpmq --whatprovides 'perl($modname)'";
        $K->post( main => log_step => $modname => "Checking if module is packaged upstream");
        $self->run_command( $cmd => "_check_upstream_availability_result" );
    };
}

{   # install_from_upstream
    override install_from_upstream => sub {
        super();
        $K->yield( get_rpm_lock => "_install_from_upstream_with_rpm_lock" );
    };

    #
    # _install_from_upstream_with_rpm_lock( )
    #
    # really install module from distribution, now that we have a lock
    # on rpm operations.
    #
    event _install_from_upstream_with_rpm_lock => sub {
        my $self = shift;
        my $modname = $self->module->name;
        my $cmd = "sudo urpmi --auto 'perl($modname)'";
        $self->run_command( $cmd => "_install_from_upstream_result" );
    };
}

{ # upstream_import_package
    override upstream_import_package => sub {
        super();
        my $self = shift;
        my $srpm = $self->srpm;
        my $cmd = "mgarepo import $srpm";
        $self->run_command( $cmd => "_upstream_import_package_result" );
    };
}

{ # upstream_build_package
    override upstream_build_package => sub {
        super();
        my $self = shift;
        my $pkgname = $self->pkgname;
        my $cmd = "mgarepo submit $pkgname";
        $self->run_command( $cmd => "_upstream_build_package_result" );
    };

    override _upstream_build_wait => sub {
        my $self = shift;
        $self->yield( "_upstream_build_wait_request" );
    };

    event _upstream_build_wait_request => sub {
        my $self = shift;
        my $pkgname = $self->pkgname;
        my $url = "http://pkgsubmit.mageia.org/?package=$pkgname&last";
        my $request = HTTP::Request->new(HEAD => $url);
        $K->post( $self->_ua => request => _upstream_build_wait_answer => $request );
    };

    event _upstream_build_wait_answer => sub {
        my ($self, $requests, $answers) = @_[OBJECT, ARG0, ARG1];
        my $answer = $answers->[0];
        my $status = $answer->header( 'x-bs-package-status' ) // "?";
        my $modname = $self->module->name;
        given ( $status ) {
            when ( "uploaded" ) {
                # nice, we finally made it!
                my $min = 1;
                $K->post( main => log_comment => $modname =>
                    "module successfully built, waiting $min minutes to index it" );
                # wait some time to be sure package has been indexed
                $K->delay( _upstream_build_package_ready => $min * 60 );
            }
            when ( "failure" ) {
                my $url = "http://pkgsubmit.mageia.org/";
                $self->yield( _upstream_build_package_failed => $url );
            }
            default {
                # no definitive result, wait a bit before checking again
                $K->post( main => log_comment => $modname =>
                    "still not ready (current status: $status), waiting 1 more minute" );
                $K->delay( _upstream_build_wait_request => 60 );
            }
        }
    };
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 DESCRIPTION

This class implements Mageia specificities that a general worker doesn't
know how to handle. It inherits from L<App::CPAN2Pkg::Worker::RPM>.

