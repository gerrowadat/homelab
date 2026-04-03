job "z2m" {
  priority = 100
  datacenters = ["home"]
  group "z2m_servers" {

    volume "z2m" {
      type            = "csi"
      source          = "z2m"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "z2m_server" {
      service {
        name = "z2m"
        port = "z2m"
      }
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
        image = "koenkk/zigbee2mqtt:2.9.2"
        volumes = [
          # udev is needed so the container can detect the Conbee stick's device path.
          "/run/udev:/run/udev:ro",
        ]
        ports = ["z2m"]
        # privileged is required for direct USB/serial device access.
        privileged = true
      }
      volume_mount {
        volume      = "z2m"
        destination = "/app/data"
      }
      resources {
        cpu    = 100
        memory = 256
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
