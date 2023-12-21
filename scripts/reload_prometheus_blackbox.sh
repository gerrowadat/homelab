#!/bin/bash

if [ "$USER" != "root" ] || [ "$PWD" != "/things/homelab" ]
then
  echo "Must be run as root from /things/homelab"
  exit
fi

# Update prom configs
sudo -u nobody git pull

curl -X POST http://prom-blackbox-exporter.home.nomad.andvari.net:9115/-/reload
