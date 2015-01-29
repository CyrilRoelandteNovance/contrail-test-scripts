#!/bin/bash

if [ -e 'localrc' ]
then
  . localrc
fi

. utils

# collect informations about the infra
. /etc/openstack_credentials

# CONTROLLERS
get_nodes opencontrail::control | while read HOSTNAME
do
  CONTROLLER_NAMES="$CONTROLLER_NAMES $HOSTNAME"
  CONTROLLER_IPS="$CONTROLLER_IPS $( dig +short $HOSTNAME )"
done

# COLLECTORS
get_nodes opencontrail::analytics | while read HOSTNAME
do
  COLLECTOR_IPS="$COLLECTOR_IPS $( dig +short $HOSTNAME )"
done

# CONFIGS
get_nodes opencontrail::config | while read HOSTNAME
do
  CONFIG_IPS="$CONFIG_IPS $( dig +short $HOSTNAME )"
done



