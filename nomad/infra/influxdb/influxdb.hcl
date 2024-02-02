job "influxdb" {
  datacenters = ["home"]
  group "influxdb_servers" {
   
    task "influxdb_server" {
      service {
	      name = "influxdb"
        port = "influxdb"
      }
      driver = "docker"
      config {
        image = "influxdb:2.7.4"
        volumes = [
          "/mnt/data/influxdb2:/var/lib/influxdb2",
        ]
        labels {
          group = "influxdb"
        }
        ports = ["influxdb"]
      }
      resources {
        cpu = 1000
        memory = 512
     }
    }

    network {
      mode = "host"
      port "influxdb" {
        static = "8086"
      }
    }

  }
}
