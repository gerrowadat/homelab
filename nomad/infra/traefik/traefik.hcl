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
      port "admin" { static = 8888 }
    }

    task "traefik" {
      driver = "docker"

      # GCP service account key for DNS-01 ACME challenge.
      # Same Nomad variable used by the old certbot job.
      template {
        data        = "{{ with nomadVar `nomad/jobs/traefik` }}{{ .gcp_credentials_json }}{{ end }}"
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
    forwardedHeaders:
      trustedIPs:
        # Newt (Pangolin tunnel agent) runs in Docker bridge mode somewhere in
        # the Nomad cluster. Pangolin terminates SSL and re-proxies HTTP with
        # X-Forwarded-For set to the real client IP. If Newt is on the same
        # host as Traefik the connection arrives from the Docker bridge
        # (172.17.0.1); if on a different host, Docker NATs through that
        # host's LAN IP, so we trust the whole homelab LAN.
        - "172.17.0.0/16"
        - "192.168.100.0/24"
        - "127.0.0.1/32"
  websecure:
    address: ":443"
    forwardedHeaders:
      trustedIPs:
        - "172.17.0.0/16"
        - "192.168.100.0/24"
        - "127.0.0.1/32"
  traefik:
    address: ":8888"

certificatesResolvers:
  le:
    acme:
      email: "{{ with nomadVar "nomad/jobs/traefik" }}{{ .acme_email }}{{ end }}"
      storage: /data/acme.json
      dnsChallenge:
        # lego's built-in gcloud provider; uses GCE_SERVICE_ACCOUNT_FILE + GCE_PROJECT.
        provider: gcloud
        # Use public resolvers for propagation checks. The local resolvers find
        # ns1.home.andvari.net authoritative (split-horizon) and return NXDOMAIN
        # for the challenge record, even though Cloud DNS has it correctly.
        resolvers:
          - "8.8.8.8:53"
          - "8.8.4.4:53"

providers:
  # Native Nomad provider -- discovers services from the Nomad service catalog.
  # Jobs opt in to routing by adding traefik.enable=true and router tags.
  nomad:
    endpoint:
      address: "http://192.168.100.250:4646"
      token: "{{ with nomadVar "nomad/jobs/traefik" }}{{ .nomad_token }}{{ end }}"
  # File provider for dynamic config (middlewares etc.) that isn't tied to a service.
  file:
    filename: /etc/traefik/dynamic.yml

api:
  dashboard: true
  # Dashboard is served on the traefik entrypoint (port 8888), which is not
  # exposed externally -- insecure mode is fine here.
  insecure: true

ping: {}

log:
  level: DEBUG

accessLog:
  fields:
    headers:
      defaultMode: drop
      names:
        X-Forwarded-For: keep
        X-Real-Ip: keep
EOH
        destination = "local/traefik.yml"
      }

      # Dynamic configuration: middlewares and path-based routes for all
      # home.andvari.net subdirectories. Hostname-based routes (e.g.
      # birbs.home.andvari.net) use Nomad service tags instead.
      # Add a router + service pair here for each path-based backend.
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
        ipStrategy:
          # Use the real client IP from X-Forwarded-For (depth=1 = leftmost,
          # i.e. the original client as seen by the first proxy -- Pangolin).
          # Without this, ipAllowList checks RemoteAddr (172.17.0.1 via Newt)
          # rather than the forwarded IP.
          depth: 1

  routers:
    sonarr:
      rule: "Host(`home.andvari.net`) && PathPrefix(`/tv`)"
      tls:
        certResolver: le
      middlewares: [internal-only]
      service: sonarr
    radarr:
      rule: "Host(`home.andvari.net`) && PathPrefix(`/movies`)"
      tls:
        certResolver: le
      middlewares: [internal-only]
      service: radarr
    miniflux:
      rule: "Host(`home.andvari.net`) && PathPrefix(`/rss`)"
      tls:
        certResolver: le
      middlewares: [internal-only]
      service: miniflux
    monitoring-webhook:
      rule: "Host(`home.andvari.net`) && PathPrefix(`/webhooks/monitoring-reload`)"
      tls:
        certResolver: le
      service: monitoring-webhook

  services:
    # Consul DNS resolves these to wherever the service is currently running.
    sonarr:
      loadBalancer:
        servers:
          - url: "http://sonarr.service.home.consul:8989"
    radarr:
      loadBalancer:
        servers:
          - url: "http://radarr.service.home.consul:7878"
    miniflux:
      loadBalancer:
        servers:
          - url: "http://miniflux.service.home.consul:8080"
    monitoring-webhook:
      loadBalancer:
        servers:
          - url: "http://monitoring-webhook.service.home.consul:9111"
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
