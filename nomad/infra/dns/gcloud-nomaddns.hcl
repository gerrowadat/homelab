job "gcloud-nomaddns" {
  datacenters = ["home"]

  group "gcloud-nomaddns_servers" {

    task "gcloud-nomaddns_worker" {
      service {
        name = "gcloud-nomaddns"
        port = "gcloud-nomaddns"
      }

      template {
        data = "{{ with nomadVar \"cloud_dns_key\" }}{{ .json }}{{ end }}"
        destination = "secrets/cloud-dns.key.json"
        perms = 700
      }

      driver = "docker" 
      config {
        image = "gerrowadat/clouddns-sync:0.0.7"
        labels {
          group = "gcloud-nomaddns"
        }
      }
      env {
        GCLOUD_VERB = "nomad_sync"
        GCLOUD_DNS_INTERVAL_SECS = "60"
        GCLOUD_DNS_ZONE = "home-nomad"
        NOMAD_SERVER_URI = "http://hedwig.home.andvari.net:4646/"
        JSON_KEYFILE = "/secrets/cloud-dns.key.json"
        HTTP_PORT = "8823"
      }
    }
    network {
      mode = "host"
      port "gcloud-nomaddns" {
        static = 8823
      }
    }
  }
}
