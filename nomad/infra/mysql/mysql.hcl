job "mysql" {
  datacenters = ["home"]
  priority = 90
  group "mysql_servers" {

    volume "mysql" {
      type            = "csi"
      source          = "mysql"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "mysql" {
      service {
        name = "mysql"
        port = "mysql"
        check {
          name     = "TCP Connection Check"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      driver = "docker"
      config {
        image = "mysql:8.4"
        ports = ["mysql"]
        labels {
          group = "mysql"
        }
      }

      volume_mount {
        volume      = "mysql"
        destination = "/var/lib/mysql"
      }

      template {
        data = <<EOH
{{- with nomadVar "nomad/jobs/mysql" -}}
MYSQL_ROOT_PASSWORD={{ .root_password }}
{{- end -}}
EOH
        destination = "secrets/mysql_env"
        env         = true
      }

      env {
        TZ = "Europe/Dublin"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }

    network {
      port "mysql" {
        static = "3306"
      }
    }

  }
}
