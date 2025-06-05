job "nut2mqtt" {
  datacenters = ["home"]
  group "nut2mqtt_servers" {
    count = 1
     constraint {
      distinct_hosts = true
    }  
    task "nut2mqtt" {
      driver = "docker" 
      config {
        image = "gerrowadat/nut2mqtt:0.1.4"
        labels {
          group = "nut2mqtt"
        }
        ports = ["nut2mqtt"]
        command = "nut2mqtt"
        args = [
          "--upsd-hosts=duckseason",
          "--mqtt-topic-base=nut2mqtt/",
          "--mqtt-host=mqtt.home.andvari.net",
          "--http-listen=:3494"
        ]
      }
     template {
       data = <<EOH
{{- with nomadVar "nomad/jobs/nut2mqtt" -}}
MQTT_USER={{ .mqtt_user }}
MQTT_PASSWORD={{ .mqtt_pass }}
{{- end -}}
EOH
      destination = "secrets/mqtt.txt"
      env = true
    }
     env {
       TZ = "Europe/Dublin"
     }
    }

    network {
      port "nut2mqtt" {
        static = "3494"
      }
    }

  }
}
