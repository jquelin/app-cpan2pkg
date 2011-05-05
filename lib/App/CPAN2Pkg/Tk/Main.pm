use 5.012;
use strict;
use warnings;

package App::CPAN2Pkg::Tk::Main;
# ABSTRACT: main cpan2pkg window

use Moose;
use MooseX::Has::Sugar;
use MooseX::POE;
use MooseX::SemiAffordanceAccessor;
use Readonly;
use Tk;
use Tk::Balloon;
use Tk::PNG;
use Tk::Sugar;

with 'Tk::Role::HasWidgets';

use App::CPAN2Pkg::Tk::Utils qw{ image };
use App::CPAN2Pkg::Utils     qw{ $SHAREDIR };

Readonly my $K  => $poe_kernel;
Readonly my $mw => $poe_main_window; # already created by poe


# -- attributes

# it's not usually a good idea to retain a reference on a poe session,
# since poe is already taking care of the references for us. however, we
# need the session to call ->postback() to set the various gui callbacks
# that will be fired upon gui events.
has _session => ( rw, weak_ref, isa=>'POE::Session' );


# -- initialization

#
# START()
#
# called as poe session initialization.
#
sub START {
    my ($self, $session) = @_[OBJECT, SESSION];
    $K->alias_set('main');
    $self->_set_session($session);
    $self->_build_gui;
}


# -- events

event new_module_wanted => sub {
    my $self = shift;
    my $entry = $self->_w( "ent_module" );
    say $entry->get;
};


# -- gui creation

#
# $main->_build_gui;
#
# create the various gui elements.
#
sub _build_gui {
    my $self = shift;
    my $s = $self->_session;

    # hide window during its creation to avoid flickering
    $mw->withdraw;

    # prettyfying tk app.
    # see http://www.perltk.org/index.php?option=com_content&task=view&id=43&Itemid=37
    $mw->optionAdd('*BorderWidth' => 1);

    # set windowtitle
    $mw->title('cpan2pkg');
    $mw->iconimage( image( $SHAREDIR->file('icon.png') ) );
    $mw->iconmask ( '@' . $SHAREDIR->file('icon-mask.xbm') );

    # make sure window is big enough
    #my $config = Games::Pandemic::Config->instance;
    #my $width  = $config->get( 'win_width' );
    #my $height = $config->get( 'win_height' );
    #$mw->geometry($width . 'x' . $height);

    # the tooltip
    $self->_set_w('tooltip', $mw->Balloon);

    #
    my $ftop = $mw->Frame->pack( top, fillx );
    $ftop->Label( -text => 'New module wanted:' )->pack( left );
    my $entry = $ftop->Entry()->pack( left, xfillx );
    $self->_set_w( ent_module => $entry );
    $ftop->Button( -text => 'submit',
        -command => $s->postback( 'new_module_wanted' ),
    )->pack( left );
    $mw->bind( '<Return>', $s->postback( 'new_module_wanted' ) );

    #
    $mw->Label( -text=>'Legend', -bg=>'black', -fg=>'white' )->pack( top, fillx );

    my $legend = $mw->Frame->pack( top, fillx );
    my @lab1 = ( 'not started', 'missing dep', 'building', 'installing', 'available', 'error' );
    my @col1 = qw{ black yellow orange blue green red };
    my @lab2 = ( 'not started', 'not available', 'importing', 'building', 'available', 'error' );
    my @col2 = qw{ black yellow purple orange green red };
    $legend->Label( -text => 'Local' )->grid( -row => 0, -column => 0, -sticky => 'w' );
    $legend->Label( -text=>'Build System' )->grid( -row=>1, -column=>0, -sticky=>'w' );
    my $buldir = $SHAREDIR->subdir( 'bullets' );
    foreach my $i ( 0 .. $#lab1 ) {
        $legend->Label( -image=>image( $buldir->file($col1[$i] . ".png")) )->grid( -row=>0, -column=>2*$i+1 );
        $legend->Label( -image=>image( $buldir->file($col2[$i] . ".png")) )->grid( -row=>1, -column=>2*$i+1 );
        $legend->Label( -text => $lab1[$i] )->grid( -row=>0, -column=>$i*2+2, -sticky => 'w' );
        $legend->Label( -text => $lab2[$i] )->grid( -row=>1, -column=>$i*2+2, -sticky => 'w' );
    }

    my $f = $mw->Frame->pack( top, xfill2 );
    my $hlist = $f->Scrolled( 'HList',
        -scrollbars => 'osoe',
        -width      => 30,
        -columns    => 3,
        -header     => 1,
    )->pack( left, filly );
    $hlist->header( create => 0, -text => 'local' );
    $hlist->header( create => 1, -text => 'bs' );
    $hlist->header( create => 2, -text => 'module' );

    # WARNING: we need to create the toolbar object before anything
    # else. indeed, tk::toolbar loads the embedded icons in classinit,
    # that is when the first object of the class is created - and not
    # during compile time.
#    $self->_build_toolbar;
#    $self->_build_menubar;
#    $self->_build_canvas;

    # center & show the window
    # FIXME: restore last position saved?
    $mw->Popup;
    $self->_w("ent_module")->focus;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=for Pod::Coverage
    START

