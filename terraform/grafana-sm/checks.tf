locals {
  probe_ids = data.grafana_synthetic_monitoring_probes.available.probes
}

resource "grafana_synthetic_monitoring_check" "http" {
  for_each = var.http_checks

  job       = each.key
  target    = each.value.target
  enabled   = true
  frequency = each.value.frequency

  # Resolve probe names to IDs; skip any name not available in this account's probe list.
  probes = [
    for name in each.value.probes : local.probe_ids[name]
    if contains(keys(local.probe_ids), name)
  ]

  # Note: check labels are UI metadata only — they do NOT appear in Prometheus
  # metric labels. Alerting behaviour is driven by the job name convention:
  # prefix job names with "internal-" for endpoints that must not be reachable.

  settings {
    http {
      ip_version          = "V4"
      valid_status_codes  = each.value.valid_status_codes
      no_follow_redirects = each.value.no_follow_redirects

      fail_if_body_matches_regexp     = each.value.fail_if_body_matches_regexp
      fail_if_body_not_matches_regexp = each.value.fail_if_body_not_matches_regexp
    }
  }
}
