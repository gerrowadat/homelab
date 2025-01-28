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

    task "prom-alertmanager_server" {
      driver = "docker" 

      template {
        data = "{{ with nomadVar \"nomad/jobs/prom-alertmanager\" }}{{ .prom_alertmanager_yml }}{{ end }}"
        destination = "local/alertmanager.yml"
        change_mode = "signal"
        change_signal = "SIGHUP"
        perms = 744
      }

      config {
        image = "prom/alertmanager"
        //volumes = [
        //  "/things/docker/prom-alertmanager:/data"
        //]
        args = ["--config.file=/local/alertmanager.yml",
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
