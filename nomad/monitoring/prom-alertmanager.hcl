job "prom-alertmanager" {
  datacenters = ["home"]
  group "prom-alertmanager_servers" {

    volume "monitoring" {
      type = "csi"
      source = "monitoring"
      read_only = false
      attachment_mode = "file-system"
      access_mode = "multi-node-multi-writer"
    }

    volume "gitrepo" {
      type = "csi"
      source = "gitrepo"
      read_only = true
      attachment_mode = "file-system"
      access_mode = "multi-node-multi-writer"
    }

    task "prom-alertmanager_server" {
      service {
        name = "prom-alertmanager"
        port = "prom-alertmanager"
      }
      driver = "docker"

      config {
        image = "prom/alertmanager:v0.31.1"
        args = ["--config.file=/config/monitoring/prom-alertmanager.yml",
                "--storage.path=/data/prom-alertmanager",
                "--web.external-url=http://prom-alertmanager.service.home.consul:9093/"]
        labels {
          group = "prom-alertmanager"
        }
        ports = ["prom-alertmanager"]
        dns_search_domains = ["home.andvari.net"]
      }
      volume_mount {
        volume = "monitoring"
        destination = "/data"
      }
      volume_mount {
        volume = "gitrepo"
        destination = "/config"
      }
      resources {
        cpu    = 100
        memory = 64
     }
    }

    network {
      port "prom-alertmanager" {
        static = "9093"
      }
    }

  }
}
