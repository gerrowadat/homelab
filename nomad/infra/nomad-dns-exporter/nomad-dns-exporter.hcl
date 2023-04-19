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
	      port = "nomad-dns-exporter"
      }
      driver = "docker" 
      config {
        image = "gerrowadat/nomad-dns-exporter:0.0.4"
        labels {
          group = "nomad-dns-exporter"
        }
        ports = ["nomad-dns-exporter"]
      }
      env {
        NOMAD_SERVER = "${attr.unique.hostname}.home.andvari.net"
        DNS_HOSTNAME = "0.0.0.0"
        DNS_PORT = "5333"
      }
    }
    network {
      mode = "host"
      port "nomad-dns-exporter" {
        static = "5333"
      }
    }
  }
}
