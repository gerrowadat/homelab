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
      driver = "docker" 

      config {
        image = "prom/alertmanager"
        args = ["--config.file=/config/monitoring/alertmanager.yml",
                "--web.external-url=http://prom-alertmanager.home.nomad.andvari.net:9093/",
                "--storage.path=/data/prom-alertmanager"]
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
