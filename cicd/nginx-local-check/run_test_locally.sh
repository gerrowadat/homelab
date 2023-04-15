#!/bin/bash

LOCAL_CONFIG=/things/homelab/nomad/infra/web/default.conf

if [ ! -f "dummy-privkey.pem" ]
then
  echo "Creating Dummy fullchain.pem/privkey.pem..."
  ./create_dummy_certs.sh
fi

if [ "$1" != "" ]
then
  if [ -f $1 ]
  then
    LOCAL_CONFIG=$1
  else
    echo "No such file : $1"
    exit
  fi
fi

echo "Testing $LOCAL_CONFIG..."

docker run --rm -t -a stdout --name test-nginx \
  -v $PWD/local-haproxy-upstreams.conf:/local/local-haproxy-upstreams.conf:ro \
  -v /things/homelab/nomad/infra/web/default.conf:/etc/nginx/conf.d/default.conf \
  -v /things/docker/ssl:/etc/letsencrypt:ro \
  -v $PWD/dummy-fullchain.pem:/secrets/home.andvari.net-fullchain.pem \
  -v $PWD/dummy-privkey.pem:/secrets/home.andvari.net-privkey.pem:ro \
  -v $PWD/dummy-fullchain.pem:/secrets/news.home.andvari.net-fullchain.pem:ro \
  -v $PWD/dummy-privkey.pem:/secrets/news.home.andvari.net-privkey.pem:ro \
  nginx:latest nginx -c /etc/nginx/nginx.conf -t
