job "prom-blackbox-exporter" {
  datacenters = ["home"]
  group "prom-blackbox-exporter_servers" {

    volume "gitrepo" {
      type = "csi"
      source = "gitrepo"
      read_only = true
      attachment_mode = "file-system"
      access_mode = "multi-node-multi-writer"
    }

    task "prom-blackbox-exporter_server" {
      service {
	      name = "prom-blackbox-exporter"
	      port = "prom-blackbox-exporter"
      }
      driver = "docker" 
      config {
        image = "prom/blackbox-exporter"
        args = ["--config.file=/config/monitoring/prom-blackbox-exporter.yml"]
        labels {
          group = "prom-blackbox-exporter"
        }
        ports = ["prom-blackbox-exporter"]
        dns_search_domains = ["home.andvari.net"]
      }
      volume_mount {
        volume = "gitrepo"
        destination = "/config"
      }
      resources {
        cpu = 1000
        memory = 1000
     }
    }

    network {
      port "prom-blackbox-exporter" {
        static = "9115"
      }
    }

  }
}
