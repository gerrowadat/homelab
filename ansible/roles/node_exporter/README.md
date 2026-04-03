# node_exporter role

Installs `prometheus-node-exporter` from the distro's apt repository and
ensures the service is enabled and running. The exporter listens on port 9100.

All physical hosts are Debian/Ubuntu-based so the apt package is the simplest
approach — no binary downloads or architecture detection needed.

## Running the playbook

```bash
cd ansible
ansible-playbook -i inventory.yml site.yml --limit node_exporter
```
