job "traefik" {
  datacenters = ["home"]

  group "traefik" {
    count = 1

    # Pinned to hedwig: owns ports 80/443 and persists acme.json on local SSD.
    # If you move this to another host, create /localssd/traefik there and
    # copy acme.json across to avoid re-requesting all certificates.
    constraint {
      attribute = "${attr.unique.hostname}"
      value     = "hedwig"
    }

    network {
      mode = "host"
      port "http"  { static = 80 }
      port "https" { static = 443 }
      # Admin/dashboard -- only reachable on the internal network.
      port "admin" { static = 8080 }
    }

    task "traefik" {
      driver = "docker"

      # GCP service account key for DNS-01 ACME challenge.
      # Same Nomad variable used by the old certbot job.
      template {
        data        = "{{ with nomadVar `cloud_dns_key` }}{{ .json }}{{ end }}"
        destination = "secrets/gcp-credentials.json"
        perms       = "600"
      }

      # GCE env vars for lego's built-in gcloud DNS provider.
      template {
        data = <<EOH
GCE_SERVICE_ACCOUNT_FILE=/secrets/gcp-credentials.json
{{ with nomadVar "nomad/jobs/traefik" -}}
GCE_PROJECT={{ .gce_project }}
{{- end }}
EOH
        destination = "secrets/traefik.env"
        env         = true
      }

      # Traefik static configuration.
      template {
        data = <<EOH
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
  admin:
    address: ":8080"

certificatesResolvers:
  le:
    acme:
      email: "{{ with nomadVar "nomad/jobs/traefik" }}{{ .acme_email }}{{ end }}"
      storage: /data/acme.json
      dnsChallenge:
        # lego's built-in gcloud provider; uses GCE_SERVICE_ACCOUNT_FILE + GCE_PROJECT.
        provider: gcloud

providers:
  # Native Nomad provider -- discovers services from the Nomad service catalog.
  # Jobs opt in to routing by adding traefik.enable=true and router tags.
  nomad:
    endpoint:
      address: "http://127.0.0.1:4646"
      token: "{{ with nomadVar "nomad/jobs/traefik" }}{{ .nomad_token }}{{ end }}"
  # File provider for dynamic config (middlewares etc.) that isn't tied to a service.
  file:
    filename: /etc/traefik/dynamic.yml

api:
  dashboard: true
  # Dashboard is served on the admin entrypoint (port 8080), which is not
  # exposed externally -- insecure mode is fine here.
  insecure: true

ping: {}

log:
  level: INFO
EOH
        destination = "local/traefik.yml"
      }

      # Dynamic configuration: middlewares referenced by service tags.
      template {
        data = <<EOH
http:
  middlewares:
    internal-only:
      ipAllowList:
        # Restricts access to the homelab LAN. Apply to any router that
        # should not be reachable from the internet.
        sourceRange:
          - "192.168.100.0/24"
EOH
        destination = "local/dynamic.yml"
      }

      config {
        image = "traefik:v3.3"
        ports = ["http", "https", "admin"]
        volumes = [
          "local/traefik.yml:/etc/traefik/traefik.yml",
          "local/dynamic.yml:/etc/traefik/dynamic.yml",
          # acme.json persists across container restarts on hedwig's local SSD.
          # Must exist before first run: mkdir -p /localssd/traefik
          "/localssd/traefik:/data",
        ]
      }

      service {
        name = "traefik"
        port = "admin"
        check {
          type     = "http"
          path     = "/ping"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
