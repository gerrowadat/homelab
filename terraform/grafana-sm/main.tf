terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.0"
    }
  }
}

provider "grafana" {
  url             = var.grafana_cloud_url
  auth            = var.grafana_api_key
  sm_access_token = var.sm_access_token
  sm_url          = var.sm_url
}

data "grafana_synthetic_monitoring_probes" "available" {}
