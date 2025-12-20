#!/bin/bash

# go install github.com/gerrowadat/nomad-homelab/nomad-conf@latest

nomad-conf upload default.conf nomad/jobs/web:nginx_cf
