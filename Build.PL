#!/usr/bin/env perl
use warnings;
use strict;

# perl Build.PL --install_base /path/to/foo
# ./Build installdeps
# ./Build install

# ./Build manifest
# ./Build dist

use Module::Build;
my $build = Module::Build->new(
    dist_name     => 'rsstoemail',
    dist_version_from => 'lib/R2E.pm',
    dist_abstract => 'Convert RSS feeds and send to email',
    license       => 'perl',
    dist_author   => 'Randall Smith <perlstalker@vuser.org>',
    script_file   => 'bin/rss2email',
    configure_requires => {
        'Module::Build'           => '0.38',
    },
    requires      => {
        'perl'                     => '5.10.0',
        'MooseX::App'              => '1.10',
        'Try::Tiny'                => 0,
        'Moose'                    => 0,
	'MooseX::Method::Signatures' => 0,
        'YAML::XS'                 => 0,
        'XML::Simple'              => '2.18',
	'Email::MIME'              => 0,
	'Email::Stuffer'           => 0,
	#'XML::RSS::Parser'         => 0,
	'XML::RAI'                 => 0,
	'XML::FeedPP'              => 0,
	'HTML::Tidy'               => 0,
	'File::Temp'               => 0,
        'Parallel::ForkManager'    => 0,
	'LWP'                      => 0,
	'DateTime'                 => 0,
	'DateTime::Format::SQLite' => 0,
	'DateTime::Format::RSS'    => 0,
	'DateTime::Format::Mail'   => 0,
	'DBI'                      => 0,
	'DBD::SQLite'              => 0,
	'DBIx::Class::Schema'      => 0,
	'SQL::Translator'          => '0.11016',
	'Digest::SHA3'             => 0,
    },
);

$build->create_build_script;
