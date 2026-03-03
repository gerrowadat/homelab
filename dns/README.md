# dns

BIND9 configuration for the `home.andvari.net` zone, served by hedwig, donkeh, and duckseason.

| File | Purpose |
|---|---|
| `etc-bind/named.conf` | Top-level BIND9 config |
| `etc-bind/named.conf.local` | Zone definitions (forward, reverse, consul forwarding) |
| `etc-bind/db.home.andvari.net` | Forward zone: A records, CNAMEs |
| `etc-bind/db.100.168.192` | Reverse zone: PTR records for 192.168.100.x |
| `home.andvari.net.zone` | Canonical zone file (source of truth for external DNS) |
| `upload_home.sh` | Script to push zone to external DNS provider |

## Making DNS changes

### 1. Edit the zone file(s)

For internal DNS changes, edit files in `dns/etc-bind/`.

**Always bump the serial** in the SOA record of any zone file you modify.
The serial is in the SOA record — increment it by 1:

```
@  IN  SOA  ns1.home.andvari.net. admin.home.andvari.net. (
                21  ; Serial  ← bump this
```

**Keep forward and reverse zones in sync:**
- Every A record in `db.home.andvari.net` should have a PTR in `db.100.168.192`
- Every PTR in `db.100.168.192` should have a corresponding A record

### 2. Apply via Ansible

The `dns_server` Ansible role rsyncs `dns/etc-bind/` from the local repo to `/etc/bind/`
on all DNS servers and restarts bind9 if anything changed:

```bash
cd ansible
ansible-playbook -i inventory.yml site.yml --limit dns_server
```

DNS servers (from `ansible/inventory.yml`): **hedwig**, **donkeh**, **duckseason**.
