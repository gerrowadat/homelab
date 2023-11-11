job "gcloud-dyndns" {
  datacenters = ["home"]

  group "gcloud-dyndns_servers" {

    task "gcloud-dyndns_worker" {

      template {
        data = "{{ with nomadVar \"cloud_dns_key\" }}{{ .json }}{{ end }}"
        destination = "secrets/cloud-dns.key.json"
        perms = 700
      }

      driver = "docker" 
      config {
        image = "gerrowadat/gcloud-dyndns:0.0.3"
        labels {
          group = "gcloud-dyndns"
        }
      }
      env {
        GCLOUD_DNS_INTERVAL_SECS = "600"
        GCLOUD_DNS_ZONE = "home"
        GCLOUD_DNS_RECORD_NAME = "home.andvari.net."
        JSON_KEYFILE = "/secrets/cloud-dns.key.json"
      }
    }
  }
}
