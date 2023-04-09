job "prom-alertmanager" {
  datacenters = ["home"]
  group "prom-alertmanager_servers" {
    task "prom-alertmanager_server" {
      service {
	      name = "prom-alertmanager"
	      port = "prom-alertmanager"
      }
      driver = "docker" 
      config {
        image = "prom/alertmanager"
        volumes = [
          "/things/homelab/monitoring:/config",
          "/things/docker/prom-alertmanager:/data"
        ]
        args = ["--config.file=/config/prom-alertmanager.yml",
                "--storage.path=/data"]
        labels {
          group = "prom-alertmanager"
        }
        ports = ["prom-alertmanager"]
        dns_servers = ["192.168.100.250", "192.168.100.251", "192.168.100.253"]
        dns_search_domains = ["home.andvari.net"]
      }
      resources {
        cpu = 1000
        memory = 1000
     }
    }

    network {
      port "prom-alertmanager" {
        static = "9093"
      }
    }

  }
}
