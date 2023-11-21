job "restic-hedwig-localssd" {
  datacenters = ["home"]
  group "restic-hedwig-localssd_servers" {

    // Only run on hedwig.
    constraint {
      attribute = "${attr.unique.hostname}"
      value = "hedwig"
    }

    task "restic_server" {

      template { 
        data = "{{ with nomadVar \"restic/hedwig_localssd\" }}{{ .ssh_key }}{{ end }}"
        destination = "secrets/hedwig_localssd-ssh-key"
        perms = "700"
      }
      template { 
        data = <<EOF
[hedwig_localssd]
sshkeyfile=/secrets/hedwig_localssd-ssh-key
repository={{ with nomadVar "restic/hedwig_localssd" }}{{ .repo }}{{ end }}
repo_password={{ with nomadVar "restic/hedwig_localssd" }}{{ .repo_pass }}{{ end }}
local_dir=/localssd
interval_hrs=24
EOF
        destination = "secrets/config.ini"
      }
      service {
	      name = "restic-hedwig-localssd"
	      port = "restic_http"
      }
      driver = "docker" 
      config {
        image = "gerrowadat/resticrunner:0.0.2"
        volumes = [
          "/localssd:/localssd:ro",
          # no keys here, just config and known_hosts.
          "/things/docker/restic/dotssh:/root/.ssh"
        ]
        labels {
          group = "restic"
        }

        ports = ["restic_http"]
      }
      env {
        RESTIC_JOBS = "hedwig_localssd"
        HTTP_PORT = "8902"
      }
    }

    network {
      port "restic_http" {
        static = "8902"
      }
    }
  }
}

