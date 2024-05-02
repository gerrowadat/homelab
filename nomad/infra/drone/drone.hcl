job "drone" {
  datacenters = ["home"]
  group "drone_servers" {
    // Run on a pi.
    constraint {
      attribute = "${attr.cpu.arch}"
      operator = "!="
      value = "amd64"
    }
    task "drone-server" {
      driver = "docker" 
      config {
        image = "drone/drone:2"
        labels {
          group = "drone"
        }
        ports = ["drone-server-http", "drone-server-https"]
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
     {{- end -}}
EOH
        destination = "drone.env"
        env = true
      }
      env {
       TZ = "Europe/Dublin"
       DRONE_SERVER_PROTO = "https"
       DRONE_USER_FILTER = "gerrowadat"
      }
    }
    task "drone-runner-docker" {
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
       DRONE_RUNNER_NAME = "drone-runner-docker"
      }
    }
    network {
      port "drone-server-http" {
        static = 3338
        to = 80
      }
      port "drone-server-https" {
        static = 3339
        to = 443
      }
      port "drone-runner-docker" {
        static = 3340
        to = 3000
      }
    }
  }
}
