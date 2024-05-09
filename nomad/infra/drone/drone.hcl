job "drone" {
  datacenters = ["home"]
  group "drone_servers" {

    task "drone-server" {
      // Run on a pi.
      constraint {
        attribute = "${attr.cpu.arch}"
        operator = "=="
        value = "arm64"
      }
      driver = "docker" 
      config {
        image = "drone/drone:2"
        labels {
          group = "drone"
        }
        ports = ["drone-server-http"]
      }
      resources {
        cpu = 1000
        memory = 512
      }

      template {
        data = <<EOH
{{- with nomadVar "nomad/jobs/drone" -}}
# Externally-addressable host
DRONE_SERVER_HOST={{ .serverhost }}
# openssl rand -hex 16
DRONE_RPC_SECRET={{ .rpcsecret }}
#Github stuff
DRONE_GITHUB_CLIENT_ID={{ .githubclientid }}
DRONE_GITHUB_CLIENT_SECRET={{ .githubclientsecret }}
# converter endpoint (pathschanged)
DRONE_CONVERT_PLUGIN_SECRET={{ .ymlpluginsecret }}
DRONE_CONVERT_PLUGIN_ENDPOINT="http://{{ env "NOMAD_ADDR_drone_yml_converter_pathschanged_http" }}"
# postgres
DRONE_DATABASE_DRIVER=postgres
DRONE_DATABASE_DATASOURCE="postgres://drone:{{ .postgres_pass }}@postgres.home.nomad.andvari.net:5432/drone?sslmode=disable"
{{- end -}}
EOH
        destination = "secrets/drone.env"
        env = true
      }
      env {
       TZ = "Europe/Dublin"
       DRONE_SERVER_PROTO = "https"
       DRONE_USER_FILTER = "gerrowadat"
      }
    }

    task "drone-yml-converter-pathschanged" {
      driver = "docker" 
      config {
        image = "meltwater/drone-convert-pathschanged"
        labels {
          group = "drone"
        }
        ports = ["drone-yml-converter-pathschanged-http"]
      }
      template {
        data = <<EOH
{{- with nomadVar "nomad/jobs/drone" -}}
DRONE_SECRET={{ .ymlpluginsecret }}
TOKEN={{ .githubrepotoken }}
{{- end -}}
EOH
        destination = "drone.env"
        env = true
      }
      env {
       TZ = "Europe/Dublin"
       DRONE_DEBUG = true
       PROVIDER = "github"
      }
    }

    network {
      port "drone-server-http" {
        static = 3338
        to = 80
      }
      port "drone-yml-converter-pathschanged-http" {
        static = 3339
        to = 3000
      }
    }
  }

  group "drone_runners_arm64" {

    task "drone-runner-docker-arm64" {
      // Run on a pi.
      constraint {
        attribute = "${attr.cpu.arch}"
        operator = "=="
        value = "arm64"
      }
      driver = "docker"
      config {
        image = "drone/drone-runner-docker:1"
        labels {
          group = "drone"
        }
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
        ports = ["drone-runner-docker"]
      }
      

      template {
        data = <<EOH
     {{- with nomadVar "nomad/jobs/drone" -}}
     # Externally-addressable host
     DRONE_RPC_HOST={{ .serverhost }}
     # openssl rand -hex 16
     DRONE_RPC_SECRET={{ .rpcsecret }}
     {{- end -}}
EOH
        destination = "drone.env"
        env = true
      }
      env {
       TZ = "Europe/Dublin"
       DRONE_RPC_PROTO = "https"
       DRONE_USER_FILTER = "gerrowadat"
       DRONE_RUNNER_CAPACITY = 2
       DRONE_RUNNER_NAME = "drone-runner-docker-arm64"
      }
    }
    network {
      port "drone-runner-docker" {
        static = 3340
        to = 3000
      }
    }
  }

  group "drone_runners_amd64" {

    task "drone-runner-docker-amd64" {
      // Run on a nuc.
      constraint {
        attribute = "${attr.cpu.arch}"
        operator = "=="
        value = "amd64"
      }
      driver = "docker"
      config {
        image = "drone/drone-runner-docker:1"
        labels {
          group = "drone"
        }
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
        ports = ["drone-runner-docker"]
      }
      

      template {
        data = <<EOH
     {{- with nomadVar "nomad/jobs/drone" -}}
     # Externally-addressable host
     DRONE_RPC_HOST={{ .serverhost }}
     # openssl rand -hex 16
     DRONE_RPC_SECRET={{ .rpcsecret }}
     {{- end -}}
EOH
        destination = "drone.env"
        env = true
      }
      env {
       TZ = "Europe/Dublin"
       DRONE_RPC_PROTO = "https"
       DRONE_USER_FILTER = "gerrowadat"
       DRONE_RUNNER_CAPACITY = 2
       DRONE_RUNNER_NAME = "drone-runner-docker-amd64"
      }
    }


    network {
      port "drone-server-http" {
        static = 3338
        to = 80
      }
      port "drone-runner-docker" {
        static = 3340
        to = 3000
      }
    }
  }
}
