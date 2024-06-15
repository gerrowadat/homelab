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
      mode = "host"
      port "octoprint" {
        static = "8888"
        to = "80"
      }
    }

  }
}
