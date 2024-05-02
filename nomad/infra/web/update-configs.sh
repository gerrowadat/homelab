#!/bin/bash

# go install github.com/gerrowadat/nomad-homelab/nomad-conf@latest

nomad-conf upload haproxy.cfg nomad/jobs/web:haproxy_cfg
nomad-conf upload default.cf nomad/jobs/web:nginx_cf
