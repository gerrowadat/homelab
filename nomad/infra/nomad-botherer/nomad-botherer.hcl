job "nomad-botherer" {
  datacenters = ["home"]
  type        = "service"

  group "nomad-botherer" {

    // amd64 constraint also ensures this runs on a Nomad server node --
    // the only non-server in the cluster is the Raspberry Pi (arm64).
    constraint {
      attribute = "${attr.cpu.arch}"
      operator  = "="
      value     = "amd64"
    }

    task "nomad-botherer" {
      driver = "docker"

      // Authenticate to Nomad via workload identity + ACL login exchange.
      // A raw WI JWT is rejected by Nomad's Job.Plan RPC (500 "UUID must be 36
      // characters"), so nomad-botherer (>= 0.9.1) exchanges this named
      // identity's JWT for a real ACL token via POST /v1/acl/login (see the
      // NOMAD_LOGIN_* env below) and re-exchanges it before expiry. The named
      // identity's aud must match the nomad-workloads auth method's
      // bound_audiences (nomad.io); the default identity's aud does not, which
      // is why a dedicated named identity is used. Capabilities come from the
      // nomad-botherer policy, granted on login by the binding rule
      //   value.nomad_job_id == "nomad-botherer"
      // (see nomad/acl/README.md). No static token to manage or rotate.
      identity {
        name = "nomad-api"
        aud  = ["nomad.io"]
        file = true
        // ttl is required: without it Nomad issues a non-expiring JWT and never
        // rewrites the file, so once the exchanged ACL token expires (~30m) the
        // re-login presents a stale JWT the auth method rejects and botherer
        // loses access. With ttl set, Nomad issues an expiring JWT and renews
        // the file (~2/3 through the ttl) so a valid JWT is always present.
        // change_mode = noop: renewals must not restart the task (botherer
        // re-reads the file itself).
        ttl         = "1h"
        change_mode = "noop"
      }

      config {
        image = "ghcr.io/gerrowadat/nomad-botherer:0.9.1"
        ports = ["nomad-botherer"]
      }

      template {
        destination = "secrets/env"
        env         = true
        data        = <<EOF
GIT_REPO_URL=https://github.com/gerrowadat/homelab
GIT_BRANCH=main
HCL_DIR=nomad
LISTEN_ADDR=:9112
WEBHOOK_PATH=/webhooks/nomad-botherer
NOMAD_ADDR=http://nomad.service.home.consul:4646
LOG_LEVEL=debug
WEBHOOK_SECRET={{ with nomadVar "nomad/jobs/nomad-botherer" }}{{ .github_webhook_secret }}{{ end }}
API_KEY={{ with nomadVar "nomad/jobs/nomad-botherer" }}{{ .github_webhook_secret }}{{ end }}
NOMAD_LOGIN_AUTH_METHOD=nomad-workloads
NOMAD_LOGIN_JWT_FILE=/secrets/nomad_nomad-api.jwt
EOF
      }

      service {
        name = "nomad-botherer"
        port = "nomad-botherer"
        check {
          name     = "HTTP health check"
          type     = "http"
          path     = "/healthz"
          interval = "30s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    network {
      mode = "host"
      port "nomad-botherer" {
        static = "9112"
      }
    }
  }
}
