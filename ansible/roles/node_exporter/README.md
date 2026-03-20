# node_exporter role

Installs `prometheus-node-exporter` from the distro's apt repository and
ensures the service is enabled and running. The exporter listens on port 9100.

All physical hosts are Debian/Ubuntu-based so the apt package is the simplest
approach — no binary downloads or architecture detection needed.

## Hosts not managed by Ansible

`tings` is scraped by Prometheus but is not in the Ansible inventory. To
install node_exporter there manually:

```bash
sudo apt-get update && sudo apt-get install -y prometheus-node-exporter
sudo systemctl enable --now prometheus-node-exporter
```

## Running the playbook

```bash
cd ansible
ansible-playbook -i inventory.yml site.yml --limit node_exporter
```
