job "nut2mqtt" {
  datacenters = ["home"]
  group "nut2mqtt_servers" {
    count = 2
     constraint {
      distinct_hosts = true
    }  
    task "nut2mqtt" {
      // Run on machines with attached UPS.
      constraint {
        attribute = "${attr.unique.hostname}"
        operator = "set_contains_any"
        value = "hedwig,duckseason"
      }
      driver = "docker" 
      config {
        image = "gerrowadat/nut2mqtt:0.0.1"
        labels {
          group = "nut2mqtt"
        }
        ports = ["nut2mqtt"]
        command = "nut2mqtt"
        args = [
          "--upsd_host=${attr.unique.hostname}.home.andvari.net",
          "--mqtt_topic_base=nut2mqtt/${attr.unique.hostname}/",
          "--mqtt_host=mqtt.home.andvari.net"
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
