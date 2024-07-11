job "z2m" {
  priority = 100
  datacenters = ["home"]
  group "z2m_servers" {
   
    task "z2m_server" {
      # The machine with the conbee.
      constraint {
        attribute = "${attr.unique.hostname}"
        value = "picluster4"
      }
      driver = "docker" 
      config {
        image = "koenkk/zigbee2mqtt:1.39.0"
        volumes = [
          "/things/docker/z2m:/app/data",
          "/run/udev:/run/udev:ro",
        ]
        labels {
          group = "z2m"
        }
        ports = ["z2m"]
        privileged = true
        devices = [
          {
            host_path = "/dev/ttyACM0"
            container_path = "/dev/ttyACM0"
          }
        ]
      }
      resources {
        cpu = 2000
        memory = 1024
     }
     env {
       TZ = "Europe/Dublin"
     }
    }

    network {
      port "z2m" {
        static = "8081"
      }
    }

  }
}
