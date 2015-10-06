#!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

config_path=~/.ZAP_D/config.xml
zap_path=/usr/local/ZAP_Dev_Build/zap.sh

git_update() {
	pushd $1
	git pull origin master
	popd
}

git_update ~/workspace/mediawiki
git_update ~/workspace/mediawiki-extensions/MobileFrontend

time ~/workspace/wikimedia-security-automated-scanning/bin/run_scan.pl \
	-xH \
	-c ~/.wmf.conf \
	-C $config_path \
	-p $zap_path \
	-b ~/workspace/mediawiki/tests/browser \
	beta_en

time ~/workspace/wikimedia-security-automated-scanning/bin/run_scan.pl \
	-xH \
	-c ~/.wmf.conf \
	-C $config_path \
	-p $zap_path \
	-b ~/workspace/mediawiki-extensions/MobileFrontend/tests/browser \
	beta_en_mobile

