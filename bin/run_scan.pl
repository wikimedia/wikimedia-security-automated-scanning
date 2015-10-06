#!/usr/bin/env perl

$| = 1;

use perl5i::2;
no warnings 'experimental::smartmatch';

use Data::Dump::Streamer;
use DateTime;
use Getopt::Lucid qw( :all );
use Mojo::UserAgent;
use Proc::Background;
use Sysadm::Install qw/ask blurt_atomic cd cdback tap/;
use XML::Tiny::DOM;
use Config::Tiny;

my @specs = (
	List("--browser-test-path|-b"),
	Param("--config|-c"),
	Switch("--debug|-d"),
	Switch("--headless|-H"),
	Switch("--help|-h"),
	Switch("--verbose|-v"),
	Switch("--use-xvfb|-x"),
	Param("--zap-config|-C"),
	Param("--zap-path|-p"),
);

# Config and options variables
my $opt = Getopt::Lucid->getopt( \@specs )->validate;
my $wmf_config = Config::Tiny->read( $opt->get_config );
if (!defined $wmf_config ) {
	die 'Could not open WMF config file';
}
my $zap_config;
try {
	$zap_config = XML::Tiny::DOM->new(
		$opt->get_zap_config, {strict_entity_parsing => 1}
	);
}
catch {
	die 'Could not open ZAP config file';
};

# Global variables
my ($context, $environment, $proxy_location, $session_name, $target, $zap_process);
my $api_key = $zap_config->api->key;
{
	my $proxy = $zap_config->proxy;
	$proxy_location = join(':', $proxy->ip ne '' ? $proxy->ip : '127.0.0.1', $proxy->port);
}

sub debug ($) {
	return 1
		unless $opt->get_debug;

	say $_[0];
}

sub verbose_status ($) {
	return 1
		unless $opt->get_verbose;

	print $_[0];
}

sub verbose ($) {
	return 1
		unless $opt->get_verbose;

	say $_[0];
}

func poll ($to_call, $waiting_for) {
	verbose_status "Waiting for $waiting_for completion: 0%", 1;

	sleep(10);

	my $res = rest_call($to_call);

	while ( $res->{'status'} < 100 ) {
		verbose_status "..." . $res->{'status'} . '%', 1;
		sleep(10);
		$res = rest_call($to_call);
	}

	verbose "...100%";
}

func rest_call ($command, $timeout) {
	my $print_verbose = 1;
	my $call = '';
	my $check = func { return 1; };
	my $ua = Mojo::UserAgent->new;
	$ua->connect_timeout($timeout ? $timeout : 5);


	for ($command) {
		when (/^version/) {
			$call = '/JSON/core/view/version/'
		}
		when (/^list_contexts/) {
			$call = '/JSON/context/view/contextList/?zapapiformat=JSON'
		}
		when (/^list_spider_scans/) {
			$call = '/JSON/spider/view/scans/?zapapiformat=JSON'
		}
		when (/^home_directory/) {
			$call = '/JSON/core/view/homeDirectory/?zapapiformat=JSON';
		}

		when (/^new_session/) {
			my $date = DateTime->now()->strftime("%F_%R");
			$session_name = $date . '_' . $environment;
			$call = "/JSON/core/action/newSession/?zapapiformat=JSON&apikey=$api_key&name=$session_name&overwrite=2"
		}
		# Script directory should already be set in config.xml
		when (/^enable_header_script/) {
			$call = "/JSON/script/action/enable/?zapapiformat=JSON&apikey=$api_key&scriptName=Add_Header.js"
		}
		# File must be placed on server in ~/.ZAP/contexts
		when (/^import_context/) {
			$call = "/JSON/context/action/importContext/?zapapiformat=JSON&apikey=$api_key&contextFile=$context"
		}
		when (/^remove_default_context/) {
			$call = "/JSON/context/action/removeContext/?zapapiformat=JSON&apikey=$api_key&contextName=Default+Context"
		}

		when (/^set_spider_depth/) {
			$call = "/JSON/spider/action/setOptionMaxDepth/?zapapiformat=JSON&apikey=$api_key&Integer=1"
		}
		when (/^spider_scan/) {
			$call = "/JSON/spider/action/scan/?zapapiformat=JSON&apikey=$api_key&url=$target&maxChildren=0"
		}
		when (/^spider_status/) {
			$print_verbose = 0;
			$call = "/JSON/spider/view/status/?zapapiformat=JSON&scanId=0"
		}

		# Scanner param info src/org/parosproxy/paros/core/scanner/ScannerParam.java
		when (/^ascan_scan/) {
			$call = "/JSON/ascan/action/scan/?zapapiformat=JSON&apikey=$api_key&url=$target&recurse=&inScopeOnly=&scanPolicyName=MW-automated&method=&postData="
		}
		when (/^ascan_status/) {
			$print_verbose = 0;
			$call = "/JSON/ascan/view/status/?zapapiformat=JSON&scanId=0"
		}

		when (/^htmlreport/) {
			$call = "/OTHER/core/other/htmlreport/?apikey=$api_key";
		}

		when (/^xmlreport/) {
			$call = "/OTHER/core/other/xmlreport/?apikey=$api_key";
		}

		when (/^save_session/) {
			$call = "/JSON/core/action/saveSession/?zapapiformat=JSON&apikey=$api_key&name=$session_name&overwrite=2"
		}

		when (/^shutdown/) {
			$call = "/JSON/core/action/shutdown/?zapapiformat=JSON&apikey=$api_key"
		}
	}

	verbose "Calling $command." if $print_verbose;

	my $complete_call = 'http://' . $proxy_location . $call;
	debug $complete_call;

	my $res;
	if ($call =~ m/^\/JSON/) {
		$res = $ua->get($complete_call)->res->json;
	}
	else {
		$res = $ua->get($complete_call)->res->body;
	}
	debug Dump($res)->Out();

	return $res;
}

func start_zap ($zap_path) {
	verbose 'Starting ZAP.';
	my $xvfb = $opt->get_use_xvfb ? 'xvfb-run -a ' : '';
	my $daemon = $opt->get_headless ? ' -daemon' : '';
 	$zap_process = Proc::Background->new($xvfb . $zap_path . $daemon . " &> /dev/null &");

	# Loop here waiting for ZAP to fully initialize, as
	# indicated by a successful result from version
	my $res;
	do { $res = rest_call('version', 1) }
		while (!$res);
}

func run_browser_tests (@paths) {

	$ENV{'BROWSER_HTTP_PROXY'} = $proxy_location;
	$ENV{'BROWSER'} = 'firefox';
	$ENV{'HEADLESS'} = $opt->get_headless ? 'true' : 'false';
	$ENV{'HEADLESS_REUSE'} = 'false';

	foreach my $path (@paths) {
		verbose "Running browser tests from $path.";

		cd($path);
		my ($stdout, $stderr, $exit_code) = tap('bundle', qw/exec cucumber/);
		cdback();

		debug "Cucumber exited with code $exit_code";
	}
}

func main ($env) {
	for ($env) {
		when (/^vagrant/) {
			$environment = $env;
			$target = 'http://127.0.0.1:8080/';
			$context = 'MW-automated-vagrant.context';
			$ENV{'MEDIAWIKI_ENVIRONMENT'} = 'mw-vagrant-host';
		}
		when (/^beta_en$/) {
			$environment = $env;
			$target = 'http://en.wikipedia.beta.wmflabs.org/';
			$context = 'MW-automated-beta-en.context';
			$ENV{'MEDIAWIKI_ENVIRONMENT'} = 'beta';
			$ENV{'MEDIAWIKI_USER'} = $wmf_config->{'cucumber'}->{'username'};
			$ENV{'MEDIAWIKI_PASSWORD'} = $wmf_config->{'cucumber'}->{'password'};
		}
		when (/^beta_en_mobile$/) {
			$environment = $env;
			$target = 'http://en.m.wikipedia.beta.wmflabs.org/';
			$context = 'MW-automated-beta-en-mobile.context';
			$ENV{'MEDIAWIKI_ENVIRONMENT'} = 'beta';
			$ENV{'MEDIAWIKI_USER'} = $wmf_config->{'cucumber'}->{'username'};
			$ENV{'MEDIAWIKI_PASSWORD'} = $wmf_config->{'cucumber'}->{'password'};
		}
		default {
			die 'Invalid environment specified.';
		}
	}

	start_zap($opt->get_zap_path);

	my $res;

	$res = rest_call('new_session');

	$res = rest_call('enable_header_script');

	$res = rest_call('import_context');

	$res = rest_call('remove_default_context');

	$res = rest_call('set_spider_depth');

	for ($environment) {
		when (/^vagrant$/) {
			ask('Now run browsertests; hit Enter when complete.', "", undef);
		}
		when (/(?:^vagrant_auto$|^beta)/) {
			run_browser_tests($opt->get_browser_test_path);
		}
	}

	$res = rest_call('spider_scan');

	poll('spider_status', 'spider_scan');

	$res = rest_call('ascan_scan');

	poll('ascan_status', 'ascan_scan');

	$res = rest_call('home_directory');
	my $report_path = $res->{'homeDirectory'} . "/$session_name";

	$res = rest_call('xmlreport');
	blurt_atomic( $res, "$report_path.xml", {utf8 => 1} );

	$res = rest_call('htmlreport');
	blurt_atomic( $res, "$report_path.html", {utf8 => 1} );

	$res = rest_call('shutdown');
	while ( $zap_process->alive ) {
		verbose 'Waiting for ZAP to shutdown';
		sleep 1;
	}
}

main( $ARGV[0] ? $ARGV[0] : '' );

