#!perl
#
# This file is part of App::CPAN2Pkg.
# Copyright (c) 2009 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

use strict;
use warnings;
use Test::More tests => 4;

BEGIN {
    use_ok( 'App::CPAN2Pkg' );
    use_ok( 'App::CPAN2Pkg::Curses' );
    use_ok( 'App::CPAN2Pkg::Module' );
    use_ok( 'App::CPAN2Pkg::Worker' );
}

diag( "Testing App::CPAN2Pkg $App::CPAN2Pkg::VERSION, Perl $], $^X" );
