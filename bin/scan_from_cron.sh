#!/bin/bash

export PATH=~/.gem/ruby/2.0.0/bin:~/perl5/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PERL5LIB=/home/dpatrick/perl5/lib/perl5
export GEM_HOME=~/.gem/ruby/2.0.0

config_path=~/.ZAP_D/config.xml
zap_path=~/ZAP_Dev_Build/zap.sh

time ~/workspace/automated-scanning/bin/run_scan.pl \
	-xH \
	-c $config_path \
	-p $zap_path \
	-b ~/workspace/mediawiki-core/tests/browser \
	beta_en

time ~/workspace/automated-scanning/bin/run_scan.pl \
	-xH \
	-c $config_path \
	-p $zap_path \
	-b ~/workspace/extensions/MobileFrontend/tests/browser \
	beta_en_mobile

