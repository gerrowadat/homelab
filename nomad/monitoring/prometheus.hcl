job "prometheus" {
  datacenters = ["home"]
  group "prometheus_servers" {

    task "prometheus_server" {
      service {
	      name = "prometheus"
	      port = "prometheus"
      }
      driver = "docker" 

      config {
        volumes = [
          "/things/homelab/monitoring:/config",
          "/things/docker/prometheus:/data"
        ]
        image = "prom/prometheus:v2.43.0"
        args = ["--config.file=/config/prometheus.yml",
                "--storage.tsdb.path=/data/prom-tsdb/"]
        labels {
          group = "prometheus"
        }
        ports = ["prometheus"]
        dns_servers = ["192.168.100.250", "192.168.100.251", "192.168.100.253"]
        dns_search_domains = ["home.andvari.net"]
      }
      resources {
        cpu = 2000
        memory = 2000
     }
    }

    network {
      port "prometheus" {
        static = "9090"
      }
    }

  }
}
