job "prom-consul-exporter" {
  datacenters = ["home"]
  group "prom-consul-exporter_servers" {
    task "prom-consul-exporter_server" {
      service {
	      name = "prom-consul-exporter"
	      port = "prom-consul-exporter"
      }
      driver = "docker" 
      config {
        image = "prom/consul-exporter"
        args = [
          "--consul.server=consul.service.consul:8500"
        ]
        labels {
          group = "prom-consul-exporter"
        }
        ports = ["prom-consul-exporter"]
      }
      resources {
        cpu = 500
        memory = 500
     }
    }

    network {
      port "prom-consul-exporter" {
        static = "9107"
      }
    }

  }
}
