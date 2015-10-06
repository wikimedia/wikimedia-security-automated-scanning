use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
	module_name   => 'Wikimedia::Security::AutomatedScanning',
	license       => 'perl', # TODO which license?
	dist_abstract => 'Scripts and config for automated security scanning',
	dist_author   => 'Darian Anthony Patrick <dpatrick@wikimedia.org>',
	dist_version  => '0.0.1',
	requires      => {
		'perl5i'               => 0,
		'Config::Tiny'         => 0,
		'Data::Dump::Streamer' => 0,
		'DateTime'             => 0,
		'Getopt::Lucid'        => 0,
		'HTTP::Proxy'          => 0,
		'Mojo::UserAgent'      => 0,
		'Proc::Background'     => 0,
		'Sysadm::Install'      => 0,
		'XML::Tiny::DOM'       => 0,
	},
	meta_merge => {
		resources => { repository => 'ssh://gerrit.wikimedia.org:29418/wikimedia/security/automated-scanning.git', },
	},
);

$builder->create_build_script();
