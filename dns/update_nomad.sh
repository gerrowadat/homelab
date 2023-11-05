#!/usr/bin/bash
#

docker run -v .:/cwd  gerrowadat/clouddns-sync --cloud-dns-zone=nomad-home --cloud-project=awaylab --json-keyfile=/cwd/key.json  --nomad-server-uri=http://hedwig:4646  nomad_sync
