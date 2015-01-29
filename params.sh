#!/bin/bash

if [ -e 'localrc' ]
then
	. localrc
fi

sudo rm -rf /tmp/oc-ci
mkdir /tmp/oc-ci

export http_proxy=http://pxy.int0.aub.cloudwatt.net:8123
export https_proxy=http://pxy.int0.aub.cloudwatt.net:8123

# install the last version of fabric
git clone https://github.com/fabric/fabric.git /tmp/oc-ci/fabric
pushd /tmp/oc-ci/fabric
sudo python setup.py install
popd

# clone the OC CI test
git clone https://github.com/Juniper/contrail-test.git /tmp/oc-ci/contrail-test

# collect informations about the infra
. /etc/openstack_credentials

sudo mco find -C opencontrail::webui | while read HOSTNAME
do
  WEBUI=$( dig +short $HOSTNAME )
done

# currently we do not support the test of the web ui
export __testbed_json_file__=sanity_testbed.json

export __stack_user__=$OS_USERNAME
export __stack_password__=$OS_PASSWORD
export __stack_tenant__=$OS_TENANT_NAME
export __stack_domain__=$OS_TENANT_NAME

export __multi_tenancy__=True
export __address_family__=v4
export __log_scenario__="just a simple run"

export __webui__=False


# generate config files
pushd /tmp/oc-ci/contrail-test

envsubst < sanity_params.ini.sample > sanity_params.ini

testr init
PYTHONPATH=fixtures testr run
popd
