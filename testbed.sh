#!/bin/bash

if [ -e 'localrc' ]
then
  . localrc
fi

. utils

#
# COLLECT INFORMATIONS ABOUT THE INFRA
#
. /etc/openstack_credentials

while read HOSTNAME
do
  CONTROLLER_NAMES="$CONTROLLER_NAMES $HOSTNAME"
  CONTROLLER_IPS="$CONTROLLER_IPS $( get_ip $HOSTNAME )"
done <<EOF
  $( get_nodes opencontrail::control )
EOF

while read HOSTNAME
do
  COLLECTOR_NAMES="$COLLECTOR_NAMES $HOSTNAME"
  COLLECTOR_IPS="$COLLECTOR_IPS $( get_ip $HOSTNAME )"
done <<EOF
  $( get_nodes opencontrail::analytics )
EOF

while read HOSTNAME
do
  CONFIG_NAMES="$CONFIG_NAMES $HOSTNAME"
  CONFIG_IPS="$CONFIG_IPS $( get_ip $HOSTNAME )"
done <<EOF
  $( get_nodes opencontrail::config )
EOF

while read HOSTNAME
do
  WEBUI_NAMES="$WEBUI_NAMES $HOSTNAME"
  WEBUI_IPS="$WEBUI_IPS $( get_ip $HOSTNAME )"
done <<EOF
  $( get_nodes opencontrail::webui )
EOF

while read HOSTNAME
do
  COMPUTE_NAMES="$COMPUTE_NAMES $HOSTNAME"
  COMPUTE_IPS="$COMPUTE_IPS $( get_ip $HOSTNAME )"
done <<EOF
  $( get_nodes opencontrail::compute )
EOF

#
# CONFIG FILE GENERATION
# 
rm sanity_testbed.json

cat <<EOF >>sanity_testbed.json
{
  "hosts": [
EOF

#   COLLECTORS
I=1
for HOSTNAME in $COLLECTOR_NAMES
do
  COLLECTOR_IP=$( echo -n $COLLECTOR_IPS | cut -d ' ' -f $I )
  CTL_IP=$( echo -n $CONTROLLER_IPS | cut -d ' ' -f $I )
  DATA_IP=$( echo -n $COLLECTOR_IPS | cut -d ' ' -f $I )
  cat <<EOF >>sanity_testbed.json
    $SEP
    {
      "name": "$HOSTNAME",
      "ip": "$COLLECTOR_IP",
      "control-ip": "$CTL_IP",
      "data-ip": "$DATA_IP",
      "username": "$OC_USERNAME",
      "password": "$OC_PASSWORD",
      "roles": [
        {
          "type": "collector"
        }
      ]
    }
EOF
  I=$(( $I + 1 ))
  SEP=","
done <<EOF
  $( get_nodes opencontrail::config )
EOF

#   CONFIGS
I=1
for HOSTNAME in $CONFIG_NAMES
do
  COLLECTOR_NAME=$( echo -n $COLLECTOR_NAMES | cut -d ' ' -f $I )
  CONFIG_IP=$( echo -n $CONFIG_IPS | cut -d ' ' -f $I )
  CTL_IP=$( echo -n $CONTROLLER_IPS | cut -d ' ' -f $I )
  DATA_IP=$( echo -n $COLLECTOR_IPS | cut -d ' ' -f $I )
  cat <<EOF >>sanity_testbed.json
    $SEP
    {
      "name": "$HOSTNAME",
      "ip": "$CONFIG_IP",
      "control-ip": "$CTL_IP",
      "data-ip": "$DATA_IP",
      "username": "$OC_USERNAME",
      "password": "$OC_PASSWORD",
      "roles": [
        {
          "type": "cfgm",
          "params": {
            "collector": "$COLLECTOR_NAME"
          }
        }
      ]
    }
EOF
  I=$(( $I + 1 ))
  SEP=","
done <<EOF
  $( get_nodes opencontrail::config )
EOF

#   OPENSTACK/KEYSTONE
I=1
KEYSTONE_HOSTNAME=$( echo -n $OS_AUTH_URL | sed -e 's/.*\/\/\(.*\):.*/\1/' )
KEYSTONE_IP=$( get_ip $KEYSTONE_HOSTNAME )
CTL_IP=$( echo -n $CONTROLLER_IPS | cut -d ' ' -f $I )
DATA_IP=$( echo -n $COLLECTOR_IPS | cut -d ' ' -f $I )
cat <<EOF >>sanity_testbed.json
    $SEP
    {
      "name": "$KEYSTONE_HOSTNAME",
      "ip": "$KEYSTONE_IP",
      "control-ip": "$CTL_IP",
      "data-ip": "$DATA_IP",
      "username": "$OC_USERNAME",
      "password": "$OC_PASSWORD",
      "roles": [
        {
          "type": "openstack"
        }
      ]
    }
EOF

#   CONTROLLERS (AKA BGP)
I=1
for HOSTNAME in $CONTROLLER_NAMES
do
  CTL_IP=$( echo -n $CONTROLLER_IPS | cut -d ' ' -f $I )

  CONFIG_NAME=$( echo -n $CONFIG_NAMES | cut -d ' ' -f $I )
  DATA_IP=$( echo -n $COLLECTOR_IPS | cut -d ' ' -f $I )
  DATA_NAME=$( echo -n $COLLECTOR_NAMES | cut -d ' ' -f $I )
  cat <<EOF >>sanity_testbed.json
    $SEP
    {
      "name": "$HOSTNAME",
      "ip": "$CTL_IP",
      "control-ip": "$CTL_IP",
      "data-ip": "$DATA_IP",
      "username": "$OC_USERNAME",
      "password": "$OC_PASSWORD",
      "roles": [
        {
          "type": "bgp",
          "params": {
	    "collector": "$DATA_NAME",
            "cfgm": "$CONFIG_NAME"
          }
        }
      ]
    }
EOF
  I=$(( $I + 1 ))
  SEP=","
done

#   COMPUTE
I=1
for HOSTNAME in $CONTROLLER_NAMES
do
  CTL_NAMES="${CTL_NAMES}${NEXT}\"$HOSTNAME\""
  NEXT=","
done

for HOSTNAME in $COMPUTE_NAMES
do
  COMPUTE_IP=$( echo -n $COMPUTE_IPS | cut -d ' ' -f $I )

  CONFIG_NAME=$( echo -n $CONFIG_NAMES | cut -d ' ' -f $I )
  CTL_IP=$( echo -n $CONTROLLER_IPS | cut -d ' ' -f $I )
  DATA_IP=$( echo -n $COLLECTOR_IPS | cut -d ' ' -f $I )
  DATA_NAME=$( echo -n $COLLECTOR_NAMES | cut -d ' ' -f $I )
  cat <<EOF >>sanity_testbed.json
    $SEP
    {
      "name": "$HOSTNAME",
      "ip": "$COMPUTE_IP",
      "control-ip": "$CTL_IP",
      "data-ip": "$DATA_IP",
      "username": "$OC_USERNAME",
      "password": "$OC_PASSWORD",
      "roles": [
        {
          "type": "compute",
          "params": {
	    "collector": "$DATA_NAME",
            "cfgm": "$CONFIG_NAME",
            "bgp": [
              $CTL_NAMES
            ]
          }
        }
      ]
    }
EOF
  I=$(( $I + 1 ))
  SEP=","
done

cat <<EOF >>sanity_testbed.json
  ],
  "vgw": []
}
EOF
