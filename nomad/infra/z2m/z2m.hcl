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
      # 'dialout' group gives access to the Conbee USB serial device (/dev/ttyACM*).
      # 'nobody' keeps the process unprivileged otherwise.
      user = "nobody:dialout"
      config {
        image = "koenkk/zigbee2mqtt:2.9.0"
        volumes = [
          "/things/docker/z2m:/app/data",
          # udev is needed so the container can detect the Conbee stick's device path.
          "/run/udev:/run/udev:ro",
        ]
        ports = ["z2m"]
        # privileged is required for direct USB/serial device access.
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
