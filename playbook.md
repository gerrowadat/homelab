Routine tasks playbook
======================


Make a DNS change
-----------------

```
# Edit files in 'dns/etc-bind', 
git commit -a
git push origin main

# wait 5 minutes, or run 'sudo -u nobody git pull' in /things/homelab

ansible-playbook -i ansible/inventory.yml ansible/site-dns.yml
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
