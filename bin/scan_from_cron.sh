#!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

config_path=~/.ZAP_D/config.xml
zap_path=/usr/local/ZAP_Dev_Build/zap.sh

git_update() {
	pushd $1
	git pull origin master
	popd
}

bundle_install() {
	pushd $1
	bundle install --path ~/gems/2.0.0
	popd
}

repos=(
	~/workspace/mediawiki
	~/workspace/mediawiki-extensions/MobileFrontend
	~/workspace/mediawiki-extensions/Flow
	~/workspace/mediawiki-extensions/VisualEditor
)

for repo in "${repos[@]}"
do
	git_update $repo
	bundle_install $repo
done

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

time ~/workspace/wikimedia-security-automated-scanning/bin/run_scan.pl \
	-xH \
	-c ~/.wmf.conf \
	-C $config_path \
	-p $zap_path \
	-b ~/workspace/mediawiki-extensions/Flow/tests/browser \
	beta_en

time ~/workspace/wikimedia-security-automated-scanning/bin/run_scan.pl \
	-xH \
	-c ~/.wmf.conf \
	-C $config_path \
	-p $zap_path \
	-b ~/workspace/mediawiki-extensions/VisualEditor/modules/ve-mw/tests/browser \
	beta_en

