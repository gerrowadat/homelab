#!/usr/bin/bash
#

docker run -v .:/cwd  gerrowadat/clouddns-sync --cloud-dns-zone=home --cloud-project=awaylab --json-keyfile=/cwd/key.json --zonefilename=/cwd/home.andvari.net.zone putzonefile
