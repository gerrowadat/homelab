Routine tasks playbook
======================


Make a DNS change
-----------------

```
# Edit files in 'dns/etc-bind', 
git commit -a
git push origin main

# wait 5 minutes, or run 'git pull' in /things/homelab

ansible-playbook -i ansible/inventory.yml ansible/site-dns.yml
```




