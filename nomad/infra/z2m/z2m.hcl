job "z2m" {
  priority = 100
  datacenters = ["home"]
  group "z2m_servers" {
   
    task "z2m_server" {
      # The machine with the conbee.
      constraint {
        attribute = "${attr.unique.hostname}"
        value = "picluster5"
      }
      driver = "docker" 
      user = "nobody:dialout"
      config {
        image = "koenkk/zigbee2mqtt:2.1.1"
        volumes = [
          "/things/docker/z2m:/app/data",
          "/run/udev:/run/udev:ro",
        ]
        ports = ["z2m"]
        privileged = true
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
