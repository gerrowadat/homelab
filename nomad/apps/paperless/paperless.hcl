job "paperless" {
  datacenters = ["home"]

  group "paperless" {

    # Search index and application state — fast storage on srv.
    volume "paperless-data" {
      type            = "csi"
      source          = "paperless-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    # Document library and thumbnails — bulk storage on mix.
    volume "paperless-media" {
      type            = "csi"
      source          = "paperless-media"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    # Consume (input) directory — watched for incoming documents.
    # On NFS, polling is used instead of inotify (see PAPERLESS_CONSUMER_POLLING).
    volume "paperless-consume" {
      type            = "csi"
      source          = "paperless-consume"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    # Export directory — destination for paperless-manage document_exporter.
    volume "paperless-export" {
      type            = "csi"
      source          = "paperless-export"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    # -----------------------------------------------------------------------
    # paperless-redis: task queue and background job broker.
    # Prestart sidecar: the webserver refuses to start without a Redis connection.
    # -----------------------------------------------------------------------
    task "paperless-redis" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      service {
        name = "paperless-redis"
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
        # Listen on the non-default port so this doesn't collide with
        # immich-redis (6379) if both jobs land on the same host.
        args  = ["--port", "6380"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    # -----------------------------------------------------------------------
    # paperless-gotenberg: converts Office documents and emails to PDF.
    # Prestart sidecar so it is ready before the consumer starts processing.
    # -----------------------------------------------------------------------
    task "paperless-gotenberg" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      service {
        name = "paperless-gotenberg"
        port = "gotenberg"
        check {
          type     = "tcp"
          interval = "15s"
          timeout  = "5s"
        }
      }

      config {
        image   = "docker.io/gotenberg/gotenberg:8.30.1"
        ports   = ["gotenberg"]
        # gotenberg image uses tini as its entrypoint; command must be set so
        # tini receives "gotenberg" as the executable, not the first flag.
        # JS disabled for security; allow-list restricts filesystem access.
        # Non-default port to avoid colliding with kutt (3000).
        command = "gotenberg"
        args    = [
          "--chromium-disable-javascript=true",
          "--chromium-allow-list=file:///tmp/.*",
          "--api-port=3001",
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    # -----------------------------------------------------------------------
    # paperless-tika: content extraction for Office docs and email attachments.
    # Prestart sidecar so it is ready before the consumer starts processing.
    # Java-based — needs more memory than the other sidecars.
    # -----------------------------------------------------------------------
    task "paperless-tika" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      service {
        name = "paperless-tika"
        port = "tika"
        check {
          type     = "tcp"
          interval = "15s"
          timeout  = "5s"
        }
      }

      config {
        image = "docker.io/apache/tika:3.0.0.0"
        ports = ["tika"]
      }

      resources {
        cpu        = 200
        memory     = 512
        memory_max = 1024
      }
    }

    # -----------------------------------------------------------------------
    # paperless-webserver: main web UI, REST API, and background consumer.
    # Hostname-based Traefik route defined in nomad/infra/traefik/traefik.hcl
    # (dynamic.yml template), keyed off paperless_hostname in nomad/jobs/traefik.
    # The hostname is also stored in nomad/jobs/paperless so this job can read
    # it without needing access to the traefik variable.
    # Publicly accessible — no internal-only middleware.
    # -----------------------------------------------------------------------
    task "paperless-webserver" {
      driver = "docker"

      service {
        name = "paperless"
        port = "http"
        check {
          name     = "TCP Connection Check"
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }

      template {
        data = <<EOF
{{- with nomadVar "nomad/jobs/paperless" }}
PAPERLESS_DBPASS={{ .db_password }}
PAPERLESS_SECRET_KEY={{ .secret_key }}
PAPERLESS_ADMIN_USER={{ .admin_user }}
PAPERLESS_ADMIN_PASSWORD={{ .admin_password }}
PAPERLESS_URL=https://{{ .hostname }}
PAPERLESS_ALLOWED_HOSTS={{ .hostname }},localhost
PAPERLESS_CSRF_TRUSTED_ORIGINS=https://{{ .hostname }}
{{- end }}
PAPERLESS_DBENGINE=postgresql
PAPERLESS_DBHOST=postgres.service.home.consul
PAPERLESS_DBPORT=5432
PAPERLESS_DBNAME=paperless
PAPERLESS_DBUSER=paperless
PAPERLESS_DBSSLMODE=disable
PAPERLESS_REDIS=redis://{{ env "NOMAD_IP_redis" }}:{{ env "NOMAD_PORT_redis" }}
PAPERLESS_TIKA_ENABLED=true
PAPERLESS_TIKA_ENDPOINT=http://{{ env "NOMAD_IP_tika" }}:{{ env "NOMAD_PORT_tika" }}
PAPERLESS_TIKA_GOTENBERG_ENDPOINT=http://{{ env "NOMAD_IP_gotenberg" }}:{{ env "NOMAD_PORT_gotenberg" }}
PAPERLESS_TIME_ZONE=Europe/Dublin
PAPERLESS_OCR_LANGUAGE=eng
# inotify doesn't work over NFS; poll every 60 seconds instead.
PAPERLESS_CONSUMER_POLLING=60
PAPERLESS_CONSUMPTION_DIR=/consume
PAPERLESS_MEDIA_ROOT=/media
PAPERLESS_DATA_DIR=/data
PAPERLESS_EXPORT_DIR=/export
EOF
        destination = "secrets/env"
        env         = true
      }

      config {
        image = "docker.io/paperlessngx/paperless-ngx:2.20.13"
        ports = ["http"]
      }

      volume_mount {
        volume      = "paperless-data"
        destination = "/data"
      }

      volume_mount {
        volume      = "paperless-media"
        destination = "/media"
      }

      volume_mount {
        volume      = "paperless-consume"
        destination = "/consume"
      }

      volume_mount {
        volume      = "paperless-export"
        destination = "/export"
      }

      resources {
        cpu        = 500
        memory     = 1024
        memory_max = 2048
      }
    }

    network {
      mode = "host"
      port "http"      { static = 8000 }
      port "redis"     { static = 6380 }
      port "gotenberg" { static = 3001 }
      port "tika"      { static = 9998 }
    }
  }
}
