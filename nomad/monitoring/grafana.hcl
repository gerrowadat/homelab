job "grafana" {
  datacenters = ["home"]
  group "grafana_servers" {
   
    task "grafana_server" {
      service {
        name = "grafana"
        port = "grafana"
      }
      driver = "docker" 
      config {
        image = "grafana/grafana-oss:latest"
        volumes = [
          "/things/docker/grafana:/var/lib/grafana"
        ]
        labels {
          group = "grafana"
        }
        ports = ["grafana"]
      }
      env {
        GF_AUTH_BASIC_ENABLED = "false"
        GF_SERVER_DOMAIN = "home.andvari.net"
        GF_SERVER_ROOT_URL = "https://home.andvari.net/grafana/"
        GF_SERVER_SERVE_FROM_SUB_PATH = "true"
      }
    }

    network {
      mode = "host"
      port "grafana" {
        static = "3000"
      }
    }

  }
}
