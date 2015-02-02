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
  HOSTNAME=$( echo -n $HOSTNAME | sed -e 's/\.adm\./\.usr\./' )
  CONTROLLER_IPS="$CONTROLLER_IPS $( get_ip $HOSTNAME )"

  HOSTNAME=$( echo -n $HOSTNAME | cut -d '.' -f 1 )
  CONTROLLER_NAMES="$CONTROLLER_NAMES $HOSTNAME"
done <<EOF
  $( get_nodes opencontrail::control )
EOF
echo "CONTROLLER_NAMES = $CONTROLLER_NAMES"

while read HOSTNAME
do
  HOSTNAME=$( echo -n $HOSTNAME | sed -e 's/\.adm\./\.usr\./' )
  COLLECTOR_IPS="$COLLECTOR_IPS $( get_ip $HOSTNAME )"

  HOSTNAME=$( echo -n $HOSTNAME | cut -d '.' -f 1 )
  COLLECTOR_NAMES="$COLLECTOR_NAMES $HOSTNAME"
done <<EOF
  $( get_nodes opencontrail::analytics )
EOF
echo "COLLECTOR_NAMES = $COLLECTOR_NAMES"

while read HOSTNAME
do
  HOSTNAME=$( echo -n $HOSTNAME | sed -e 's/\.adm\./\.usr\./' )
  CONFIG_IPS="$CONFIG_IPS $( get_ip $HOSTNAME )"

  HOSTNAME=$( echo -n $HOSTNAME | cut -d '.' -f 1 )
  CONFIG_NAMES="$CONFIG_NAMES $HOSTNAME"
done <<EOF
  $( get_nodes opencontrail::config )
EOF
echo "CONFIG_NAMES = $CONFIG_NAMES"

while read HOSTNAME
do
  HOSTNAME=$( echo -n $HOSTNAME | sed -e 's/\.adm\./\.usr\./' )
  WEBUI_IPS="$WEBUI_IPS $( get_ip $HOSTNAME )"

  HOSTNAME=$( echo -n $HOSTNAME | cut -d '.' -f 1 )
  WEBUI_NAMES="$WEBUI_NAMES $HOSTNAME"
done <<EOF
  $( get_nodes opencontrail::webui )
EOF
echo "WEBUI_NAMES = $WEBUI_NAMES"

while read HOSTNAME
do
  HOSTNAME=$( echo -n $HOSTNAME | sed -e 's/\.adm\./\.usr\./' )
  COMPUTE_IPS="$COMPUTE_IPS $( get_ip $HOSTNAME )"

  HOSTNAME=$( echo -n $HOSTNAME | cut -d '.' -f 1 )
  COMPUTE_NAMES="$COMPUTE_NAMES $HOSTNAME"
done <<EOF
  $( get_nodes opencontrail::compute )
EOF
echo "COMPUTE_NAMES = $COMPUTE_NAMES"

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

#   WEBUIS
I=1
for HOSTNAME in $WEBUI_NAMES
do
  WEBUI_IP=$( echo -n $WEBUI_IPS | cut -d ' ' -f $I )
  CTL_IP=$( echo -n $CONTROLLER_IPS | cut -d ' ' -f $I )
  DATA_IP=$( echo -n $COLLECTOR_IPS | cut -d ' ' -f $I )
  CONFIG_NAME=$( echo -n $CONFIG_NAMES | cut -d ' ' -f $I )
  cat <<EOF >>sanity_testbed.json
    $SEP
    {
      "name": "$HOSTNAME",
      "ip": "$WEBUI_IP",
      "control-ip": "$CTL_IP",
      "data-ip": "$DATA_IP",
      "username": "$OC_USERNAME",
      "password": "$OC_PASSWORD",
      "roles": [
        {
          "type": "webui",
          "params": {
            "cfgm": "$CONFIG_NAME"
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

I=1
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
