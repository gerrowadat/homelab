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

Alerting behaviour is driven by the job name convention:
  - Default: alert fires if all probes fail for 5m (endpoint should be reachable).
  - Prefix the job name with "internal-" for endpoints that must NOT be reachable from the
    internet. The alert fires if any probe succeeds for 5m.

Note: Grafana Cloud SM check labels do NOT appear in Prometheus metric labels, so alerting
logic cannot be driven by label values — only by the job name.
EOT
  type = map(object({
    target             = string
    probes             = optional(list(string), ["London"])
    frequency          = optional(number, 600000)  # milliseconds; default 10 minutes
    valid_status_codes = optional(list(number), [200])

    # Body matching: regexp patterns. Check fails if body matches any pattern in
    # fail_if_body_matches_regexp, or if it doesn't match any in fail_if_body_not_matches_regexp.
    fail_if_body_matches_regexp     = optional(list(string), [])
    fail_if_body_not_matches_regexp = optional(list(string), [])

    # Set to true to treat redirects as a probe result rather than following them.
    # Useful when the expected response IS a redirect (e.g. valid_status_codes = [302]).
    no_follow_redirects = optional(bool, false)
  }))
  default = {}
}
