#!/bin/bash

if [ -e 'localrc' ]
then
	. localrc
fi

WORK_DIR=${WORK_DIR:-/tmp/}
WORK_DIR=$WORK_DIR/oc-ci

sudo rm -rf $WORK_DIR
mkdir $WORK_DIR

export http_proxy=http://pxy.int0.aub.cloudwatt.net:8123
export https_proxy=http://pxy.int0.aub.cloudwatt.net:8123

# install the last version of fabric
git clone https://github.com/fabric/fabric.git $WORK_DIR/fabric
pushd $WORK_DIR/fabric
sudo python setup.py install
popd

# clone the OC CI test
git clone https://github.com/Juniper/contrail-test.git $WORK_DIR/contrail-test
pushd $WORK_DIR/contrail-test

# have to be removed when merged
git fetch https://review.opencontrail.org/Juniper/contrail-test refs/changes/85/6685/1 && git cherry-pick FETCH_HEAD
popd

export http_proxy=
export https_proxy=

# collect informations about the infra
. /etc/openstack_credentials

# generate the params file
. params

# generate the testbed file
. testbed

# start the tests
pushd $WORK_DIR/contrail-test

testr init
OS_ENDPOINT_TYPE=internalURL PYTHONPATH=fixtures testr run

popd
