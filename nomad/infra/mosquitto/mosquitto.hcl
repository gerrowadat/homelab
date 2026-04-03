job "mosquitto" {
  datacenters = ["home"]
  group "mqtt_servers" {

    constraint {
      attribute = "${attr.unique.hostname}"
      value = "hedwig"
    }

    volume "mosquitto" {
      type            = "csi"
      source          = "mosquitto"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
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
        image = "eclipse-mosquitto:2.0.22"
        labels {
          group = "mqtt"
        }
        ports = ["mqtt"]
      }
      volume_mount {
        volume      = "mosquitto"
        destination = "/mosquitto"
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
