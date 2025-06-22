#!/bin/bash

helm -n mysql upgrade mysql oci://registry-1.docker.io/bitnamicharts/mysql -f values.yaml
