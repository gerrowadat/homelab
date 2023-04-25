job "nomad-dns-exporter" {
  datacenters = ["home"]
  group "nomad-dns-exporter_servers" {
    // Only run on core machines.
    count = 3
    constraint {
      attribute = "${attr.cpu.arch}"
      operator = "="
      value = "amd64"
    }
    task "nomad-dns-exporter_server" {
      service {
        name = "nomad-dns-exporter"
	      port = "nomad-dns-exporter-http"
      }
      driver = "docker" 
      config {
        image = "gerrowadat/nomad-dns-exporter:0.0.4"
        labels {
          group = "nomad-dns-exporter"
        }
        ports = ["nomad-dns-exporter-http", "nomad-dns-exporter-dns"]
      }
      env {
        NOMAD_SERVER = "${attr.unique.hostname}.home.andvari.net"
        NOMAD_DOMAIN = ".job.nomad"
        DNS_TTL = "30"
        DNS_HOSTNAME = "0.0.0.0"
        HTTP_HOSTNAME = "0.0.0.0"
        DNS_PORT = "5333"
        HTTP_PORT = "5334"
      }
    }
    network {
      mode = "host"
      port "nomad-dns-exporter-dns" {
        static = "5333"
      }
      port "nomad-dns-exporter-http" {
        static = "5334"
      }
    }
  }
}
