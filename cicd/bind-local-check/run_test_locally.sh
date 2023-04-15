#!/bin/bash

LOCAL_CONFIG_DIR=/things/homelab/dns/etc-bind/

if [ "$1" != "" ]
then
  if [ -d $1 ]
  then
    LOCAL_CONFIG_DIR=$1
  else
    echo "No such directory : $1"
    exit
  fi
fi

echo "Testing $LOCAL_CONFIG_DIR..."

docker run --rm -t -a stdout --name test-bind-config \
  -v ${LOCAL_CONFIG_DIR}:/etc/bind:ro \
  ubuntu/bind9 named-checkconf -z /etc/bind/named.conf
