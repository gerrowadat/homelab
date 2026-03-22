locals {
  probe_ids = data.grafana_synthetic_monitoring_probes.available.probes
}

resource "grafana_synthetic_monitoring_check" "http" {
  for_each = var.http_checks

  job     = each.key
  target  = each.value.target
  enabled = true

  # Resolve probe names to IDs; skip any name not available in this account's probe list.
  probes = [
    for name in each.value.probes : local.probe_ids[name]
    if contains(keys(local.probe_ids), name)
  ]

  # source label lets Prometheus alert rules select SM checks specifically,
  # distinguishing them from local blackbox-exporter metrics.
  # alert_if_up flows through to Prometheus and drives the alert rule logic.
  labels = {
    source      = "grafana-sm"
    alert_if_up = tostring(each.value.alert_if_up)
  }

  settings {
    http {
      ip_version         = "V4"
      valid_status_codes = each.value.valid_status_codes

      fail_if_body_matches_regexp     = each.value.fail_if_body_matches_regexp
      fail_if_body_not_matches_regexp = each.value.fail_if_body_not_matches_regexp
    }
  }
}
