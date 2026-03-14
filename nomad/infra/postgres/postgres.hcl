job "postgres" {
  datacenters = ["home"]
  priority = 90
  group "postgres_servers" {
    task "postgres" {
      service {
        name = "postgres"
        port = "postgres"
        check {
          name = "TCP Connection Check"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
      constraint {
        attribute = "${attr.unique.hostname}"
        value = "hedwig"
      }
      driver = "docker"
      config {
        image = "postgres:16.13"
        volumes = [
          "/localssd/postgres:/var/lib/postgresql/data"
        ]
        labels {
          group = "postgres"
        }
        ports = ["postgres"]
      }
      resources {
        cpu = 2000
        memory = 1024
     }

     template {
       data = <<EOH
{{- with nomadVar "nomad/jobs/postgres" -}}
POSTGRES_PASSWORD={{ .pgpassword }}
{{- end -}}
EOH
      destination = "secrets/pgpassword"
      env = true
    }
     env {
       TZ = "Europe/Dublin"
       PGDATA = "/var/lib/postgresql/data"
     }
    }

    task "pgbackup" {
      driver = "docker"
      config {
        image   = "postgres:16.13"
        command = "bash"
        args    = ["/gitrepo/nomad/infra/postgres/pgbackup.sh"]
      }

      volume_mount {
        volume      = "gitrepo"
        destination = "/gitrepo"
        read_only   = true
      }

      volume_mount {
        volume      = "pgbackup"
        destination = "/backup"
      }

      template {
        data = <<EOH
{{- with nomadVar "nomad/jobs/postgres" -}}
PGPASSWORD={{ .pgpassword }}
PGBACKUP_KEY={{ .pgbackup_key }}
{{- end -}}
EOH
        destination = "secrets/pgbackup_env"
        env         = true
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    volume "gitrepo" {
      type            = "csi"
      source          = "gitrepo"
      read_only       = true
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    volume "pgbackup" {
      type            = "csi"
      source          = "pgbackup"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    network {
      port "postgres" {
        static = "5432"
      }
    }

  }
}
