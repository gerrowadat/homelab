#!/usr/bin/env python3
"""
Reconstruct terraform/grafana-sm/terraform.tfvars from the live Grafana Cloud
Synthetic Monitoring API, using credentials stored in the Nomad variable.

Use this if you've lost your local terraform.tfvars (it's gitignored).
See docs/grafana-synthetic-monitoring.md for context.

Requirements: Python 3.6+, nomad CLI in PATH, network access to Grafana Cloud.

The Nomad variable at nomad/jobs/grafana-alloy must contain:
  grafana_cloud_url   — e.g. https://yourorg.grafana.net
  grafana_api_key     — service account token (Editor/Admin role)
  sm_access_token     — Synthetic Monitoring API token
  sm_url              — SM API base URL, e.g. https://synthetic-monitoring-api.grafana.net
  grafana_metrics_host — for Alloy, e.g. prometheus-prod-01-prod-us-east-0.grafana.net
  grafana_stack_id    — numeric stack ID
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

NOMAD_VAR_PATH = "nomad/jobs/grafana-alloy"

# Path relative to this script's location
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUTPUT = os.path.join(SCRIPT_DIR, "../terraform/grafana-sm/terraform.tfvars")

REQUIRED_KEYS = ["grafana_cloud_url", "grafana_api_key", "sm_access_token", "sm_url"]


def get_nomad_var(path):
    result = subprocess.run(
        ["nomad", "var", "get", "-out=json", path],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"error: could not read Nomad variable at {path}", file=sys.stderr)
        print(result.stderr.strip(), file=sys.stderr)
        sys.exit(1)
    return json.loads(result.stdout)["Items"]


def api_get(url, token):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        print(f"error: HTTP {e.code} from {url}: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"error: could not reach {url}: {e.reason}", file=sys.stderr)
        sys.exit(1)


def labels_to_dict(labels):
    """SM API returns labels as [{name, value}, ...]; convert to dict."""
    return {entry["name"]: entry["value"] for entry in (labels or [])}


def fmt_str_list(items):
    if not items:
        return "[]"
    return "[" + ", ".join(f'"{i}"' for i in items) + "]"


def fmt_int_list(items):
    if not items:
        return "[]"
    return "[" + ", ".join(str(i) for i in items) + "]"


def render_tfvars(creds, checks, probe_id_to_name):
    lines = []
    lines.append(f'grafana_cloud_url = "{creds["grafana_cloud_url"].strip()}"')
    lines.append(f'grafana_api_key   = "{creds["grafana_api_key"].strip()}"')
    lines.append(f'sm_access_token   = "{creds["sm_access_token"].strip()}"')
    lines.append(f'sm_url            = "{creds["sm_url"].strip()}"')
    lines.append("")
    lines.append("http_checks = {")

    for check in checks:
        if "http" not in check.get("settings", {}):
            # Skip non-HTTP checks (ping, dns, tcp) — not managed by this Terraform config.
            continue

        http = check["settings"]["http"]
        labels = labels_to_dict(check.get("labels", []))
        probes = [probe_id_to_name[pid] for pid in check.get("probes", []) if pid in probe_id_to_name]
        alert_if_up = labels.get("alert_if_up", "false")
        valid_codes = http.get("validStatusCodes") or [200]
        fail_if_matches = http.get("failIfBodyMatchesRegexp") or []
        fail_if_not_matches = http.get("failIfBodyNotMatchesRegexp") or []

        lines.append(f'  "{check["job"]}" = {{')
        lines.append(f'    target             = "{check["target"]}"')
        lines.append(f'    probes             = {fmt_str_list(probes)}')
        lines.append(f'    valid_status_codes = {fmt_int_list(valid_codes)}')
        if fail_if_matches:
            lines.append(f'    fail_if_body_matches_regexp     = {fmt_str_list(fail_if_matches)}')
        if fail_if_not_matches:
            lines.append(f'    fail_if_body_not_matches_regexp = {fmt_str_list(fail_if_not_matches)}')
        lines.append(f'    alert_if_up        = {alert_if_up}')
        lines.append(f'  }}')

    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(
        description="Export Grafana Cloud SM checks to terraform.tfvars",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "-o", "--output",
        default=DEFAULT_OUTPUT,
        help=f"Output path (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite output file if it already exists",
    )
    args = parser.parse_args()

    output_path = os.path.abspath(args.output)

    if os.path.exists(output_path) and not args.force:
        print(f"error: {output_path} already exists. Use --force to overwrite.", file=sys.stderr)
        sys.exit(1)

    print(f"Reading Nomad variable {NOMAD_VAR_PATH} ...")
    creds = get_nomad_var(NOMAD_VAR_PATH)

    missing = [k for k in REQUIRED_KEYS if k not in creds]
    if missing:
        print(f"error: Nomad variable is missing required keys: {', '.join(missing)}", file=sys.stderr)
        print(f"Add them with: nomad var put {NOMAD_VAR_PATH} key=value ...", file=sys.stderr)
        sys.exit(1)

    sm_url = creds["sm_url"].strip().rstrip("/")
    if not sm_url.startswith("http"):
        sm_url = "https://" + sm_url
    sm_token = creds["sm_access_token"].strip()

    print(f"Fetching probe list from {sm_url} ...")
    probes = api_get(f"{sm_url}/api/v1/probe/list", sm_token)
    probe_id_to_name = {p["id"]: p["name"] for p in probes}

    print("Fetching check list ...")
    checks = api_get(f"{sm_url}/api/v1/check/list", sm_token)
    http_checks = [c for c in checks if "http" in c.get("settings", {})]
    print(f"Found {len(checks)} check(s) total, {len(http_checks)} HTTP check(s).")

    output = render_tfvars(creds, checks, probe_id_to_name)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        f.write(output)

    print(f"Written to {output_path}")
    print("Verify with: terraform -chdir=terraform/grafana-sm plan")


if __name__ == "__main__":
    main()
