#!/bin/bash

LOCAL_CONFIG=/things/homelab/nomad/infra/web/haproxy.cfg

if [ "$1" != "" ]
then
  if [ -d $1 ]
  then
    LOCAL_CONFIG=$1
  else
    echo "No such directory : $1"
    exit
  fi
fi

echo "Testing $LOCAL_CONFIG..."

docker run --rm -t -a stdout --name test-haproxy-config \
  -v ${LOCAL_CONFIG}:/usr/local/etc/haproxy/haproxy.cfg:ro \
  haproxy:2.7 haproxy -f /usr/local/etc/haproxy/haproxy.cfg -c
