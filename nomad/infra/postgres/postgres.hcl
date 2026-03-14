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
        args    = ["/local/backup.sh"]
      }

      template {
        data        = <<-EOH
          #!/usr/bin/env bash
          set -euo pipefail

          PGHOST=127.0.0.1
          PGUSER=postgres
          BACKUP_DIR=/backup

          until pg_isready -h "$PGHOST" -U "$PGUSER" -q; do
            echo "Waiting for postgres..."
            sleep 5
          done

          while true; do
            DATE=$(date +%Y%m%d_%H%M%S)
            echo "Starting backup at $DATE"

            DATABASES=$(psql -h "$PGHOST" -U "$PGUSER" -t -A \
              -c "SELECT datname FROM pg_database WHERE datistemplate = false")

            for db in $DATABASES; do
              echo "Backing up $db..."
              pg_dump -h "$PGHOST" -U "$PGUSER" "$db" \
                | openssl enc -aes-256-cbc -pbkdf2 -pass env:PGBACKUP_KEY \
                > "$BACKUP_DIR/${db}_${DATE}.sql.enc"
              pg_dump -h "$PGHOST" -U "$PGUSER" --schema-only "$db" \
                | openssl enc -aes-256-cbc -pbkdf2 -pass env:PGBACKUP_KEY \
                > "$BACKUP_DIR/${db}_${DATE}_schema.sql.enc"
              echo "Done backing up $db"
            done

            echo "Backup complete. Sleeping 24h."
            sleep 86400
          done
        EOH
        destination = "local/backup.sh"
        perms       = "755"
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

      volume_mount {
        volume      = "pgbackup"
        destination = "/backup"
      }

      resources {
        cpu    = 200
        memory = 256
      }
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
