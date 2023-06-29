job "mosquitto" {
  datacenters = ["home"]
  group "mqtt_servers" {

    constraint {
      attribute = "${attr.unique.hostname}"
      value = "hedwig"
    }

    task "mosquitto_server" {
      template {
        data = "{{ with nomadVar \"nomad/jobs/mosquitto\" }}{{ .passwd }}{{ end }}"
        destination = "secrets/mosquitto_passwd"
      }
      service {
        name = "mosquitto"
        port = "mqtt"
      }
      driver = "docker" 
      config {
         image = "eclipse-mosquitto:1.6.15"
         volumes = [
          "/things/docker/mosquitto:/mosquitto"
         ]
        labels {
          group = "mqtt"
        }
        ports = ["mqtt"]
      }
    }
    network {
      mode = "host"
      port "mqtt" {
        static = "1883"
      }
    }
  }
}
