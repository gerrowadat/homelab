job "postgres" {
  datacenters = ["home"]
  priority = 90
  group "postgres_servers" {
    task "postgres" {
      service {
        name = "postgres"
        port = "postgres"
        check {
          name = "TCP Connection Check"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
      constraint {
        attribute = "${attr.unique.hostname}"
        value = "hedwig"
      }
      driver = "docker" 
      config {
        image = "postgres:16.4"
        volumes = [
          "/localssd/postgres:/var/lib/postgresql/data"
        ]
        labels {
          group = "postgres"
        }
        ports = ["postgres"]
      }
      resources {
        cpu = 2000
        memory = 1024
     }

     template {
       data = <<EOH
{{- with nomadVar "nomad/jobs/postgres" -}}
POSTGRES_PASSWORD={{ .pgpassword }}
{{- end -}}
EOH
      destination = "secrets/pgpassword"
      env = true
    }
     env {
       TZ = "Europe/Dublin"
       PGDATA = "/var/lib/postgresql/data"
     }
    }

    network {
      port "postgres" {
        static = "5432"
      }
    }

  }
}
