job "freshrss" {
  datacenters = ["home"]
  group "freshrss-servers" {
    task "freshrss" {
      service {
       name = "freshrss"
       port = "freshrss-webui"
      }
      driver = "docker" 
      config {
        image = "linuxserver/freshrss:latest"
        volumes = [
          "/things/docker/freshrss:/config",
        ]
        labels {
          group = "freshrss-servers"
        }
        ports = ["freshrss-webui"]
      }
      resources {
        cpu = 500
        memory = 512
      }
      env {
        TZ = "Europe/Dublin"
        PUID = 65534
        PGID = 65534
      }
    }
    network {
      port "freshrss-webui" {
        static = 9898
        to = 80
      }
    }
  }
}
