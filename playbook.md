Routine tasks playbook
======================


Make a DNS change
-----------------

```
# Edit 'dns/home.andvari.net.zone', 
./dns/upload_home.sh
```

Change Prometheus Configs
-------------------------

```
# Edit files in 'monitoring/'
git commit -a
git push origin main
sudo -s
cd /things/homelab
scripts/reload_prometheus.sh
```

Backups
-------

See [backups/README.md](backups/README.md)

Web Serving - Add a new backend
-------------------------------

Add the backend to nomad/infra/web/haproxy.cfg -- se the other examples.

Add to the template in nomad/infra/web/web.hcl to add the new backend 'upstream', make sure to also add a dummy version to cicd/web/local-haproxy-upstreams.conf so the test pass.
