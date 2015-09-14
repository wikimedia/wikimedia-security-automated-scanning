#!/usr/bin/env perl

use perl5i::2;
use HTTP::Proxy;
use HTTP::Proxy::HeaderFilter::simple;

func main {
	my $proxy = HTTP::Proxy->new( port => 8091 );

	$proxy->push_filter(
		mime    => undef,
		request => HTTP::Proxy::HeaderFilter::simple->new(
			sub { say 'Header found.' if $_[1]->header('X-Wikimedia-Security-Audit'); },
		),
	);

	$proxy->start();
}

main();
