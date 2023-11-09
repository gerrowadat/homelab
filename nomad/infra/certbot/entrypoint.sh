#!/bin/bash

while true
do
  date
  certbot --no-random-sleep-on-renew renew
  date
  echo "sleeping 86400 seconds"
  sleep 86400
done
