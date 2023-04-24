#!/bin/bash

LOCAL_PROMETHEUS_CONFDIR=/things/homelab/monitoring

docker run --rm -v ${LOCAL_PROMETHEUS_CONFDIR}:/etc/prometheus:ro gerrowadat/docker-promtool:latest promtool check config /etc/prometheus/prometheus.yml
