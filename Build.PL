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

use Module::Build;

my %requires = (
    'Curses'             => 0,
    'Curses::UI'         => 0,
    'Curses::UI::POE'    => 0,
    'FindBin'            => 0,
    'Hook::Output::File' => 0,
    'POE'                => 0,
);
my %build_requires = (
    %requires,
    'Test::More' => 0,
);
 my %recommends = (
     'Test::Pod'           => 0,
     'Test::Pod::Coverage' => 0,
);

my $builder = Module::Build->new(
    module_name         => 'App::CPAN2Pkg',
    license             => 'perl',
    dist_author         => 'Jerome Quelin <jquelin@cpan.org>',
    dist_version_from   => 'lib/App/CPAN2Pkg.pm',
    build_requires      => \%build_requires,
    requires            => \%requires,
    recommends          => \%recommends,
    script_files        => [ 'bin/cpan2pkg' ],
    add_to_cleanup      => [
        'App-CPAN2Pkg-*', map { ( '*/' x $_ ) . '*~' } 0..5
    ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
