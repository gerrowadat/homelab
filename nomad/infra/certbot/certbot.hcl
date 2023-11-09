job "certbot" {
  datacenters = ["home"]

  group "certbot_servers" {

    // This must run on duckseason as it accesses these files directly (not over NFS).
    constraint {
      attribute = "${attr.unique.hostname}"
      operator = "="
      value = "duckseason"
    }

    task "certbot_worker" {

      template {
        data = "{{ with nomadVar \"cloud_dns_key\" }}{{ .json }}{{ end }}"
        destination = "secrets/cloud-dns.key.json"
        perms = 700
      }

      driver = "docker" 
      config {
        image = "gerrowadat/certbot:6"
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
