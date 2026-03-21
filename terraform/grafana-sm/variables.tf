variable "grafana_cloud_url" {
  description = "Grafana Cloud instance URL, e.g. https://yourorg.grafana.net"
  type        = string
}

variable "grafana_api_key" {
  description = "Grafana Cloud API key with Editor or Admin role (Service Account token)"
  type        = string
  sensitive   = true
}

variable "sm_access_token" {
  description = "Synthetic Monitoring API access token (generated in SM → Settings → API Tokens)"
  type        = string
  sensitive   = true
}

variable "sm_url" {
  description = "Synthetic Monitoring API URL for your region. Find this in SM → Settings."
  type        = string
  default     = "https://synthetic-monitoring-api.grafana.net"
}

variable "http_checks" {
  description = <<EOT
Map of HTTP synthetic monitoring checks. Key is the check job name (shown in Grafana and used
as the Prometheus `job` label). Each check runs from the specified public probe locations.

Set alert_if_up = true for endpoints that must NOT be reachable from the public internet
(e.g. internal admin UIs). The Prometheus alert rule will fire if any probe can reach them.

Set alert_if_up = false (default) for endpoints that must be reachable. The alert fires if
all probes report failure for 5 minutes.
EOT
  type = map(object({
    target             = string
    probes             = optional(list(string), ["Atlanta", "Chicago", "London", "Singapore"])
    valid_status_codes = optional(list(number), [200])

    # Body matching: regexp patterns. Check fails if body matches any pattern in
    # fail_if_body_matches_regexp, or if it doesn't match any in fail_if_body_not_matches_regexp.
    fail_if_body_matches_regexp     = optional(list(string), [])
    fail_if_body_not_matches_regexp = optional(list(string), [])

    # true  → this endpoint should NOT be reachable from the internet; alert if probe_success == 1
    # false → this endpoint should be reachable; alert if probe_success == 0
    alert_if_up = optional(bool, false)
  }))
  default = {}
}
