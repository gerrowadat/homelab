job "octoprint" {
  datacenters = ["home"]
  group "octoprint_servers" {
   
    task "octoprint_server" {
      # picluster5 is attached to the 3d printer.
      constraint {
        attribute = "${attr.unique.hostname}"
        value = "picluster5"
      }
      driver = "docker" 
      config {
        image = "octoprint/octoprint:latest"
        volumes = [
          "/things/docker/octoprint:/octoprint"
        ]
        labels {
          group = "octoprint"
        } 
        ports = ["octoprint"]
        # privileged is required for USB serial and video device access.
        privileged = true
        devices = [
         {
           host_path = "/dev/ttyACM0"
           container_path = "/dev/printer"
         },
         {
           host_path = "/dev/video0"
           container_path = "/dev/video0"
         }
        ]
      }
      env {
        ENABLE_MJPG_STREAMER = "true"
      }
    }
    network {
      # host networking is required alongside privileged mode for reliable USB
      # device access. The container listens on port 80; static = "8888" exposes
      # it on the host at 8888.
      mode = "host"
      port "octoprint" {
        static = "8888"
        to = "80"
      }
    }

  }
}
