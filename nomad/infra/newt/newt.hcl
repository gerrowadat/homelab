job "newt" {
  datacenters = ["home"]
  group "newt_servers" {
    count = 1
     constraint {
      distinct_hosts = true
    }  
    task "newt" {
      driver = "docker" 
      config {
        image = "fosrl/newt"
        labels {
          group = "newt"
        }
      }
     template {
       data = <<EOH
{{- with nomadVar "nomad/jobs/newt" -}}
PANGOLIN_ENDPOINT={{ .endpoint }}
NEWT_ID={{ .id }}
NEWT_SECRET={{ .secret }}
{{- end -}}
EOH
      destination = "secrets/newt.txt"
      env = true
    }
     env {
       TZ = "Europe/Dublin"
     }
    }
  }
}

