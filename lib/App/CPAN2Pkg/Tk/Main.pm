use 5.012;
use strict;
use warnings;

package App::CPAN2Pkg::Tk::Main;
# ABSTRACT: main cpan2pkg window

use DateTime;
use List::Util qw{ first };
use Moose;
use MooseX::Has::Sugar;
use MooseX::POE;
use MooseX::SemiAffordanceAccessor;
use Readonly;
use Tk;
use Tk::Balloon;
use Tk::HList;
use Tk::NoteBook;
use Tk::PNG;
use Tk::ROText;
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


# -- public logging events

event log_out => sub {
    my ($self, $module, $line) = @_[OBJECT, ARG0 .. $#_ ];
    my $rotext = $self->_w( "rotext_$module" );
    $rotext->insert( 'end', "$line\n" );
};
event log_err => sub {
    my ($self, $module, $line) = @_[OBJECT, ARG0 .. $#_ ];
    my $rotext = $self->_w( "rotext_$module" );
    $rotext->insert( 'end', "$line\n", "error" );
};
event log_comment => sub {
    my ($self, $module, $line) = @_[OBJECT, ARG0 .. $#_ ];
    my $rotext = $self->_w( "rotext_$module" );
    my $timestamp = DateTime->now(time_zone=>"local")->hms;
    $rotext->insert( 'end', "* $timestamp $line\n", "comment" );
};
event log_result => sub {
    my ($self, $module, $result) = @_[OBJECT, ARG0 .. $#_ ];
    my $rotext = $self->_w( "rotext_$module" );
    my $timestamp = DateTime->now(time_zone=>"local")->hms;
    $rotext->insert( 'end', "* $timestamp $result\n", "result" );
};
event log_step => sub {
    my ($self, $module, $step) = @_[OBJECT, ARG0 .. $#_ ];
    my $rotext = $self->_w( "rotext_$module" );
    $rotext->insert( 'end', "\n\n** $step\n\n", "step" );
};
event module_state => sub {
    my ($self, $module) = @_[OBJECT, ARG0 .. $#_ ];
    my $modname = $module->name;

    # find relevant line in hlist
    my $hlist = $self->_w( "hlist" );
    my @children = $hlist->info( 'children' );
    my $elem     = first { $hlist->info(data=>$_) eq $modname } @children;

    # get bullet color
    my %color = (
        "not started"   => "black",
        "not available" => "yellow",
        importing       => "purple",
        building        => "orange",
        installing      => "blue",
        available       => "green",
        error           => "red",
    );
    my $colorl = $color{ $module->local->status };
    my $coloru = $color{ $module->upstream->status };

    # update bullets
    my $bulletl  = image( $SHAREDIR->file("bullets", "$colorl.png") );
    my $bulletu  = image( $SHAREDIR->file("bullets", "$coloru.png") );
    $hlist->itemConfigure( $elem, 0, -image=>$bulletl );
    $hlist->itemConfigure( $elem, 1, -image=>$bulletu );

    $self->_w( "btn_close_$modname" )->configure( enabled )
        if $module->local->status    eq 'available'
        && $module->upstream->status eq 'available';
};

# -- public events

event new_module => sub {
    my ($self, $module) = @_[OBJECT, ARG0];
    my $modname = $module->name;

    # calculate module position in the list
    my $hlist = $self->_w('hlist');
    my @children = $hlist->info( 'children' );
    my $next = first { $hlist->info(data=>$_) gt $modname } @children;
    my @pos = defined $next ? ( -before => $next ) : ( -at => -1 );

    # create module in the list
    my $bullet = image( $SHAREDIR->file("bullets", "black.png") );
    my $elem = $hlist->addchild( "", -data=>$modname, @pos );
    $hlist->itemCreate( $elem, 0, -itemtype => 'image', -image=>$bullet );
    $hlist->itemCreate( $elem, 1, -itemtype => 'image', -image=>$bullet );
    $hlist->itemCreate( $elem, 2, -itemtype => 'text', -text=>$modname );
    $hlist->see( $elem );

    # create new pane in the notebook
    my $nb = $self->_w('notebook');
    my $pane = $nb->add( $modname, -label=>$modname );
    $nb->raise( $modname );
    my $rotext = $pane->Scrolled( 'ROText', -scrollbars => 'e' )->pack( top, xfill2 );
    $rotext->tag( configure => step   => -font => "FNbig" );
    $rotext->tag( configure => error  => -foreground => "firebrick" );
    $rotext->tag( configure => result => -foreground => "steelblue" );
    $self->_set_w( "rotext_$modname", $rotext );

    # close button
    my $b = $pane->Button(
        -text    => "Clean finished module",
        -command => $self->_session->postback( "_on_btn_clean", $modname ),
        disabled,
    )->pack( top, fillx );
    $self->_set_w( "btn_close_$modname", $b );
};


# -- gui events

event _on_btn_clean => sub {
    my ($self, $args) = @_[OBJECT, ARG0];
    my ($modname) = @$args;
    $self->_w('notebook')->delete( $modname );

    my $hlist = $self->_w( 'hlist' );
    my @children = $hlist->info( 'children' );
    my $elem     = first { $hlist->info(data=>$_) eq $modname } @children;
    $hlist->delete( entry => $elem );
};

#
# event: _on_btn_submit()
#
# received when user clicked the submit button.
#
event _on_btn_submit => sub {
    my $self = shift;
    my $entry = $self->_w( "ent_module" );
    my $module = $entry->get;
    $K->post( controller => new_module_wanted => $module );
    $entry->delete( 0, 'end' );
};

event _on_hlist_2click => sub {
    my $self = shift;
    my $hlist = $self->_w('hlist');
    my ($elem) = $hlist->info('selection');
    my $module = $hlist->info( data => $elem );
    $self->_w('notebook')->raise($module);
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

    # font used in progression text
    $mw->fontCreate( "FNbig", -weight => "bold" );

    #
    my $ftop = $mw->Frame->pack( top, fillx, pad20 );
    $ftop->Label( -text => 'New module wanted:' )->pack( left, pad2 );
    my $entry = $ftop->Entry()->pack( left, xfillx, pad2 );
    $self->_set_w( ent_module => $entry );
    $ftop->Button( -text => 'submit',
        -command => $s->postback( '_on_btn_submit' ),
    )->pack( left, pad2 );
    $mw->bind( '<Return>', $s->postback( '_on_btn_submit' ) );

    #
    my $f = $mw->Frame->pack( top, xfill2 );
    $self->_build_hlist( $f );
    $self->_build_notebook( $f );

    # center & show the window
    # FIXME: restore last position saved?
    $mw->Popup;
    $mw->minsize($mw->width, $mw->height);
    $self->_w("ent_module")->focus;
}


#
# $main->_build_hlist( $parent );
#
# build the hierarchical list holding all the module status.
#
sub _build_hlist {
    my ($self, $parent) = @_;

    my $hlist = $parent->Scrolled( 'HList',
        -scrollbars => 'osoe',
        -width      => 30,
        -columns    => 3,
        -header     => 1,
    )->pack( left, filly );
    $self->_set_w( hlist => $hlist );

    $hlist->header( create => 0, -text => 'local' );
    $hlist->header( create => 1, -text => 'bs' );
    $hlist->header( create => 2, -text => 'module' );

    $hlist->bind( '<Double-1>', $self->_session->postback('_on_hlist_2click') );
}

#
# $main->_build_notebook( $parent );
#
# build the notebook holding one pane per module being built. first tab
# contains the legend.
#
sub _build_notebook {
    my ($self, $parent) = @_;

    # create the notebook that will hold module details
    my $nb = $parent->NoteBook->pack( right, xfill2 );
    $self->_set_w('notebook', $nb);

    # create a first tab with the legend
    my $legend = $nb->add("Legend", -label=>"Legend");

    #my $legend = $mw->Frame->pack( top, fillx );
    my @lab1 = ( 'not started', 'not available', 'building', 'installing', 'available', 'error' );
    my @col1 = qw{ black yellow orange blue green red };
    my @lab2 = ( 'not started', 'not available', 'importing', 'building', 'available', 'error' );
    my @col2 = qw{ black yellow purple orange green red };
    $legend->Label( -text => 'Local' )
      ->grid( -row => 0, -column => 0, -columnspan=>2, -sticky => 'w' );
    $legend->Label( -text => 'Build System' )
      ->grid( -row => 0, -column => 2,  -columnspan=>2,-sticky => 'w' );
    my $buldir = $SHAREDIR->subdir( 'bullets' );
    foreach my $i ( 0 .. $#lab1 ) {
        $legend->Label( -image => image( $buldir->file( $col1[$i] . ".png" ) ) )
          ->grid( -row => $i + 1, -column => 0, ipad5 );
        $legend->Label( -image => image( $buldir->file( $col2[$i] . ".png" ) ) )
          ->grid( -row => $i + 1, -column => 2, ipad5 );
        $legend->Label( -text => $lab1[$i] )->grid( -row=>$i+1, -column=>1, -sticky => 'w' );
        $legend->Label( -text => $lab2[$i] )->grid( -row=>$i+1, -column=>3, -sticky => 'w' );
    }

}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=for Pod::Coverage
    START

