#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'App::CPAN2Pkg' );
}

diag( "Testing App::CPAN2Pkg $App::CPAN2Pkg::VERSION, Perl $], $^X" );
