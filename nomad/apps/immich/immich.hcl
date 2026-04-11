job "immich" {
  datacenters = ["home"]

  group "immich" {

    # Photos library — stored on mix (large media NFS share)
    volume "immich-photos" {
      type            = "csi"
      source          = "immich-photos"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    # Postgres data — stored on srv (general NFS share)
    volume "immich-db" {
      type            = "csi"
      source          = "immich-db"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    # -----------------------------------------------------------------------
    # immich-server: main API + web UI
    # Traefik routing is defined in nomad/infra/traefik/traefik.hcl
    # (dynamic.yml template), keyed off immich_hostname in nomad/jobs/traefik.
    # -----------------------------------------------------------------------
    task "immich-server" {
      driver = "docker"

      service {
        name = "immich"
        port = "http"
        check {
          name     = "HTTP Connection Check"
          type     = "http"
          path     = "/api/server/ping"
          interval = "30s"
          timeout  = "10s"
        }
      }

      template {
        data = <<EOF
DB_HOSTNAME={{ env "NOMAD_IP_db" }}
DB_PORT={{ env "NOMAD_PORT_db" }}
DB_USERNAME=immich
DB_PASSWORD={{ with nomadVar "nomad/jobs/immich" }}{{ .db_password }}{{ end }}
DB_DATABASE_NAME=immich
REDIS_HOSTNAME={{ env "NOMAD_IP_redis" }}
REDIS_PORT={{ env "NOMAD_PORT_redis" }}
IMMICH_MACHINE_LEARNING_URL=http://{{ env "NOMAD_IP_ml" }}:{{ env "NOMAD_PORT_ml" }}
EOF
        destination = "secrets/env"
        env         = true
      }

      config {
        image = "ghcr.io/immich-app/immich-server:release"
        ports = ["http"]
      }

      volume_mount {
        volume      = "immich-photos"
        destination = "/usr/src/app/upload"
      }

      resources {
        cpu        = 500
        memory     = 1024
        memory_max = 3072
      }
    }

    # -----------------------------------------------------------------------
    # wait-for-db: ephemeral prestart task — polls pg_isready until postgres
    # is accepting connections, then exits 0. Main tasks don't start until
    # all ephemeral prestart tasks have exited successfully.
    # -----------------------------------------------------------------------
    task "wait-for-db" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0"
        command = "sh"
        args    = ["-c", "until pg_isready -h ${NOMAD_IP_db} -p ${NOMAD_PORT_db} -U immich; do sleep 2; done"]
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }

    # -----------------------------------------------------------------------
    # immich-machine-learning: CLIP embeddings + facial recognition (CPU-only)
    # -----------------------------------------------------------------------
    task "immich-ml" {
      driver = "docker"

      service {
        name = "immich-ml"
        port = "ml"
        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }

      config {
        image = "ghcr.io/immich-app/immich-machine-learning:release"
        ports = ["ml"]
      }

      resources {
        cpu        = 1000
        memory     = 2048
        memory_max = 3072
      }
    }

    # -----------------------------------------------------------------------
    # immich-redis: job queue and session cache
    # Prestart sidecar: starts before immich-server and immich-ml.
    # -----------------------------------------------------------------------
    task "immich-redis" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      service {
        name = "immich-redis"
        port = "redis"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        image = "docker.io/redis:7-alpine"
        ports = ["redis"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    # -----------------------------------------------------------------------
    # immich-db: dedicated postgres with vectorchord (required by Immich).
    # Uses port 5433 to avoid collision with the shared postgres on 5432.
    # PGDATA is set to a subdirectory to avoid NFS "directory not empty" errors
    # on first initialisation.
    # Prestart sidecar: starts before immich-server and immich-ml.
    # -----------------------------------------------------------------------
    task "immich-db" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      service {
        name = "immich-db"
        port = "db"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      template {
        data = <<EOF
POSTGRES_USER=immich
POSTGRES_PASSWORD={{ with nomadVar "nomad/jobs/immich" }}{{ .db_password }}{{ end }}
POSTGRES_DB=immich
PGDATA=/var/lib/postgresql/data/pgdata
PGPORT=5433
EOF
        destination = "secrets/env"
        env         = true
      }

      config {
        image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0"
        ports = ["db"]
      }

      volume_mount {
        volume      = "immich-db"
        destination = "/var/lib/postgresql/data"
      }

      resources {
        cpu    = 300
        memory = 1024
      }
    }

    network {
      mode = "host"
      port "http"  { static = "2283" }
      port "ml"    { static = "3003" }
      port "redis" { static = "6379" }
      port "db"    { static = "5433" }
    }
  }
}
