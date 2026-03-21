job "databasus" {
  datacenters = ["home"]
  type        = "service"

  group "databasus" {

    volume "databasus" {
      type            = "csi"
      source          = "databasus"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    volume "pgbackup" {
      type            = "csi"
      source          = "pgbackup"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    volume "mysqlbackup" {
      type            = "csi"
      source          = "mysqlbackup"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    network {
      port "http" {
        static = 4005
      }
    }

    task "databasus" {
      driver = "docker"

      config {
        image = "docker.io/databasus/databasus:latest"
        ports = ["http"]
      }

      service {
        name = "databasus"
        port = "http"
        check {
          name     = "TCP Connection Check"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      volume_mount {
        volume      = "databasus"
        destination = "/databasus-data"
      }

      volume_mount {
        volume      = "pgbackup"
        destination = "/pgbackup"
      }

      volume_mount {
        volume      = "mysqlbackup"
        destination = "/mysqlbackup"
      }

      # Injects database credentials from the databasus Nomad variable.
      # See README for how to populate nomad/jobs/databasus.
      template {
        data = <<EOH
{{- with nomadVar "nomad/jobs/databasus" -}}
POSTGRES_ADMIN_PASSWORD={{ .postgres_password }}
MYSQL_ROOT_PASSWORD={{ .mysql_root_password }}
{{- end -}}
EOH
        destination = "secrets/env"
        env         = true
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
