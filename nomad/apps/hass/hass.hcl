job "hass" {
  datacenters = ["home"]

  meta {
    gitops_managed = "true"
  }

  group "hass" {
    volume "hass" {
      type            = "csi"
      source          = "hass"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    # Writes /config/configuration.yaml on first deploy if it doesn't exist.
    # On subsequent deploys it's a no-op, so it's safe to edit the file directly.
    task "hass-init" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image      = "alpine:3.20"
        entrypoint = ["/bin/sh", "/local/init.sh"]
      }

      template {
        data        = <<SCRIPT
#!/bin/sh
set -e
if [ ! -f /config/configuration.yaml ]; then
  echo "Writing initial configuration.yaml..."
  cp /local/configuration.yaml /config/configuration.yaml
  echo "Done."
else
  echo "configuration.yaml already exists, skipping."
fi
SCRIPT
        destination = "local/init.sh"
        perms       = "0755"
      }

      template {
        data = <<EOF
# Home Assistant configuration
# Written by Nomad on first deploy only. Safe to edit in-place on the volume.

homeassistant:
  name: Home
  unit_system: metric
  time_zone: Europe/Dublin
  country: IE
  external_url: "https://{{ with nomadVar "nomad/jobs/hass" }}{{ .hostname }}{{ end }}"
  internal_url: "https://{{ with nomadVar "nomad/jobs/hass" }}{{ .hostname }}{{ end }}"

# Required when running behind Traefik in host-network mode.
# Traefik connects to HA from 127.0.0.1, so that's the trusted proxy address.
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - 192.168.100.0/24

# Postgres recorder — avoids SQLite on NFS.
# Requires 'homeassistant' DB and user; see README for setup.
recorder:
  db_url: "postgresql://homeassistant:{{ with nomadVar "nomad/jobs/hass" }}{{ .db_password }}{{ end }}@postgres.service.home.consul/homeassistant"
  purge_keep_days: 30

logger:
  default: debug

default_config:
EOF
        destination = "local/configuration.yaml"
      }

      volume_mount {
        volume      = "hass"
        destination = "/config"
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }

    task "hass" {
      driver = "docker"

      service {
        name = "hass"
        port = "http"
        check {
          name     = "TCP"
          type     = "tcp"
          interval = "30s"
          timeout  = "10s"
        }
      }

      config {
        image        = "ghcr.io/home-assistant/home-assistant:2026.6.1"
        ports        = ["http"]
        network_mode = "host"
      }

      volume_mount {
        volume      = "hass"
        destination = "/config"
      }

      resources {
        cpu        = 1000
        memory     = 1024
        memory_max = 2048
      }

      env {
        TZ = "Europe/Dublin"
      }
    }

    network {
      mode = "host"
      port "http" { static = 8123 }
    }
  }
}
