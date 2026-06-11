job "diun" {
  datacenters = ["home"]
  type        = "service"

  meta {
    gitops_managed = "true"
  }

  group "diun" {

    task "diun" {
      driver = "docker"

      config {
        image = "ghcr.io/crazy-max/diun:4.33.0"
        args  = ["serve", "--config", "/secrets/diun.yml"]
      }

      // Config contains the Nomad ACL token, so it lives in secrets/.
      template {
        destination = "secrets/diun.yml"
        data        = <<EOF
db:
  path: /local/diun.db

watch:
  workers: 4
  schedule: "0 */6 * * *"
  jitter: 30s
  firstCheckNotif: false

providers:
  nomad:
    address: http://nomad.service.home.consul:4646
    secretID: {{ with nomadVar "nomad/jobs/diun" }}{{ .nomad_token }}{{ end }}
    watchByDefault: true
EOF
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
