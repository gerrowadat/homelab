# terraform/grafana-sm

Manages Grafana Cloud Synthetic Monitoring HTTP checks via Terraform.

See **[docs/grafana-synthetic-monitoring.md](../../docs/grafana-synthetic-monitoring.md)**
for the full setup guide, including:

- One-time Grafana Cloud account setup
- Creating the required Nomad variables
- How check definitions are structured
- Alert logic (public vs `internal-` prefixed checks)
- Recovering a lost `terraform.tfvars`

## Quick reference

```bash
# First-time setup
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — fill in credentials and define checks

terraform init
terraform plan
terraform apply

# See available probe locations for your account
terraform console
> data.grafana_synthetic_monitoring_probes.available.probes

# Recover a lost terraform.tfvars from the live API
python3 ../../scripts/grafana-sm-export-tfvars.py
```

`terraform.tfvars` is gitignored — do not commit it.
