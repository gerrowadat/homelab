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

See `nomad/infra/traefik/README.md` for the full playbook.

Short version: if the service is a Nomad job, add `traefik.*` tags to its
`service` block and redeploy the job. If it's externally managed (e.g. sonarr),
add a router + service entry to the `dynamic.yml` template in
`nomad/infra/traefik/traefik.hcl` and redeploy the traefik job.
