job "databasus" {
  datacenters = ["home"]
  type        = "service"

  meta {
    gitops_managed = "true"
    gitops_update_policy = "image-only"
  }

  group "databasus" {

    update {
      auto_revert = true
      health_check = "checks"
      healthy_deadline = "5m"
    }

    volume "databasus" {
      type            = "csi"
      source          = "databasus"
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
        image = "docker.io/databasus/databasus:v3.47.0"
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

      resources {
        cpu    = 100
        # databasus bundles an embedded Postgres (metadata store) alongside the
        # Go app, and the scheduled backup run spikes on top of both. At 256 the
        # task pinned its limit during the nightly backup and was OOM-killed
        # (exit 137), failing the backup; idle sits ~100 MiB. 512 gives headroom.
        memory = 512
      }
    }
  }
}
