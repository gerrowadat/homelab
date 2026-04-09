# scripts

Utility scripts for operating the homelab cluster.

| Script | Purpose |
|---|---|
| `check-monitoring-configs.sh` | Validate Prometheus, Alertmanager, and Blackbox Exporter configs locally (uses Docker). Run before pushing changes to `monitoring/`. CI runs the same checks. |
| `reload_prometheus.sh` | POST `/-/reload` to Prometheus via its Consul address. |
| `reload_prometheus_blackbox.sh` | POST `/-/reload` to the Blackbox Exporter via its Consul address. |
| `nomad-diff.sh` | Show a diff of what would change if a Nomad job file were submitted (dry-run helper). |
| `pg-connect.sh` | Open a psql session to the local postgres instance via its Consul address. |
| `mysql-connect.sh` | Open a mysql shell to the local mysql instance via its Consul address. |
| `check-databasus-backups.sh` | List all non-system databases (PostgreSQL + MySQL) and verify each one has a backup in the databasus volume. |
| `grafana-sm-export-tfvars.py` | Reconstruct `terraform/grafana-sm/terraform.tfvars` from the live Grafana Cloud Synthetic Monitoring API. Run this if you've lost your local tfvars. See `docs/grafana-synthetic-monitoring.md`. |
| `dump-nomad-vars.sh` | Dump all Nomad variables to an AES-256-CBC encrypted bash restore script. Use for disaster-recovery backups; restore by decrypting and piping to bash. See below. |
| `volume-shell.sh` | Start an interactive shell with a Nomad CSI volume mounted at `/<volume-name>`. Useful for inspecting or modifying volume contents directly. |

## Nomad variable backup and restore

`dump-nomad-vars.sh` dumps every Nomad variable accessible to your token as
an encrypted bash restore script. The restore script, when decrypted and
piped to bash, re-creates all variables on a fresh cluster using `nomad var put`.

### One-time setup

Create the encryption-key variable and **memorise the passphrase** — you will
need it to decrypt the dump even if the cluster is gone:

```bash
nomad var put backup/encryption-key key=<passphrase>
```

This variable is intentionally excluded from the dump; it must be re-created
manually on a new cluster before the restore script can run.

### Dumping

```bash
export NOMAD_TOKEN=<token-with-read-access>
bash scripts/dump-nomad-vars.sh
# → nomad-vars-YYYYMMDD-HHMMSS.sh.enc
```

Options:

| Flag | Effect |
|---|---|
| `-o FILE` | Write output to `FILE` instead of the auto-generated name |
| `--no-encrypt` | Write a plaintext restore script (contains secrets — handle with care) |
| `--key-path P` | Use a different Nomad variable path for the passphrase (default: `backup/encryption-key`, item: `key`) |

### Inspecting a dump

```bash
openssl enc -aes-256-cbc -pbkdf2 -d \
  -pass pass:<passphrase> -in nomad-vars-YYYYMMDD-HHMMSS.sh.enc | less
```

### Restoring to a fresh cluster

1. Create the encryption-key variable on the new cluster:
   ```bash
   nomad var put backup/encryption-key key=<passphrase>
   ```
2. Decrypt and pipe directly to bash:
   ```bash
   export NOMAD_TOKEN=<token-with-write-access>
   openssl enc -aes-256-cbc -pbkdf2 -d \
     -pass pass:<passphrase> -in nomad-vars-YYYYMMDD-HHMMSS.sh.enc | bash
   ```

Or decrypt to a file first (delete after use):

```bash
openssl enc -aes-256-cbc -pbkdf2 -d \
  -pass pass:<passphrase> -in nomad-vars-YYYYMMDD-HHMMSS.sh.enc \
  -out restore.sh
chmod 600 restore.sh
bash restore.sh
rm restore.sh
```

### Notes

- Only the **default namespace** is dumped. For other namespaces, set
  `NOMAD_NAMESPACE` and run the script again with a different output file.
- The restore script uses `nomad var put`, which overwrites existing variables
  without prompting. It is safe to run against a cluster that already has some
  of the variables.
- Requires `nomad`, `jq`, and `openssl` in `PATH`, plus `NOMAD_TOKEN`.

## Monitoring validation

Always run before pushing changes to `monitoring/`:

```bash
bash scripts/check-monitoring-configs.sh
```

This validates `prometheus.yml`, all `*.rules.yml` / alerting rule files,
and `blackbox.yml` using the same Docker images as CI.
