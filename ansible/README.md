# ansible

Provisions and configures all hosts. Runs against hosts defined in `inventory.yml`.

## Running

```bash
# All hosts
bash apply_all.sh

# Specific playbook / host subset
ansible-playbook -i inventory.yml site.yml --limit hedwig
```

`CONSUL_GOSSIP_KEY` must be set in the environment before running — it's used to
encrypt Consul cluster gossip traffic and must match across all nodes.

## Host groups

| Group | Hosts | Purpose |
|---|---|---|
| `nomadconsul` | picluster2/4/5, duckseason, hedwig, donkeh, bebop, rocksteady | Nomad clients+servers and Consul agents |
| `nfs_server` | duckseason, rabbitseason | NFS servers: duckseason exports `/export/things`; rabbitseason exports `/srv` (from `/localssd/srv`) and `/mix` (from `/localdisk/mix`) |
| `dns_server` | hedwig, donkeh, duckseason | BIND9 with Consul forwarding for `.consul` queries |
| `ups` | hedwig, duckseason | NUT for UPS monitoring |
| `login` | rabbitseason | Public-facing SSH login node |

`nomad_server: true` is set by default for nomadconsul hosts; set it explicitly to
`false` on hosts that should run as clients only (see picluster5).

## Roles

| Role | Purpose |
|---|---|
| `nomad` | Installs Nomad binary, config, and systemd unit |
| `consul` | Installs Consul binary, config, and systemd unit |
| `docker` | Installs docker-ce + containerd (Nomad's container runtime) |
| `nfs_client` | Mounts `/things` from duckseason |
| `dns_server` | Configures BIND9 with Consul DNS forwarding |
| `remove_k8s` | Strips Kubernetes packages and data dirs from a host being converted to Nomad |
| `linux_aptlike` | Common baseline packages for apt-based hosts |
| `login` | SSH hardening and user config for the login node |
| `nfs_server` | Bind-mounts source paths to NFS export paths (runs after `ansible-nfs-server`); configured via `nfs_server_bindmounts` host var |
| `ups` | NUT client config for hosts with a locally attached UPS |
| `publicsmtp` | Postfix + OpenDKIM for the public-facing mail relay |
| `publicweb` | nginx config for static public web hosting |
| `mailman` | Mailman3 mailing list config |
