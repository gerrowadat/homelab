job "letsencrypt-to-nomad-vars" {
  datacenters = ["home"]

  group "letsencrypt-to-nomad-vars_servers" {

    // This must run on duckseason as it accesses these files directly (not over NFS).
    constraint {
      attribute = "${attr.unique.hostname}"
      operator = "="
      value = "duckseason"
    }

    task "letsencrypt-to-nomad-vars" {
      template { 
        data = "{{ with nomadVar \"nomad-tokens/variable-admin\" }}{{ .tok }}{{ end }}"
        destination = "secrets/variable-admin.token"
        perms = 700
      }

      driver = "docker" 
      env {
        DOMAINS = "home.andvari.net docker-registry.home.andvari.net news.home.andvari.net"
        NOMAD_SERVER = "${attr.unique.hostname}"
        CHECK_FREQUENCY_HRS = "24"
      }
      config {
        image = "gerrowadat/letsencrypt-to-nomad-vars:14"
        volumes = [
          "/export/things/docker/ssl:/etc/letsencrypt"
        ]
        labels {
          group = "letsencrypt-to-nomad-vars"
        }
      }
    }
  }
}
