#!/bin/bash

if [ -z "$1" ]
then
	echo "Usage: $0 <dev4x name>"
	exit -1
fi
export DEV4X=$1

if [ -e 'localrc' ]
then
	. localrc
fi

export http_proxy=http://pxy.int0.aub.cloudwatt.net:8123
export https_proxy=http://pxy.int0.aub.cloudwatt.net:8123

if [ "$RECLONE" ]
then
	rm -rf contrail-fabric-utils
	git clone https://github.com/Juniper/contrail-fabric-utils.git
fi

if [ "$RECLONE" ]
then
	rm -rf contrail-test
	git clone https://github.com/Juniper/contrail-test.git
fi

. /etc/openstack_credentials


envsubst < testbed.py.tmpl > testbed.py
