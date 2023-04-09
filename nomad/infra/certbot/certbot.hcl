job "certbot" {
  datacenters = ["home"]

  type = "batch"
  periodic {
    cron = "@daily"
  }

  group "certbot_servers" {

    // This must run on duckseason as it accesses these files directly (not over NFS).
    constraint {
      attribute = "${attr.unique.hostname}"
      operator = "="
      value = "duckseason"
    }

    task "certbot_worker" {
      driver = "docker" 
      config {
        image = "gerrowadat/certbot-joker:1"
        volumes = [
          "/export/things/docker/ssl:/etc/letsencrypt"
        ]
        labels {
          group = "certbot"
        }
      }
    }
  }
}
