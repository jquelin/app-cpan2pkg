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

my $builder = Module::Build->new(
    module_name         => 'App::CPAN2Pkg',
    license             => 'perl',
    dist_author         => 'Jerome Quelin <jquelin@cpan.org>',
    dist_version_from   => 'lib/App/CPAN2Pkg.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'App-CPAN2Pkg-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
