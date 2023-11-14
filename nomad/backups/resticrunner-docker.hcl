job "resticrunner-docker" {
  datacenters = ["home"]
  group "resticrunner-docker_servers" {

    // Only run on core machines.
    constraint {
      attribute = "${attr.cpu.arch}"
      operator = "="
      value = "amd64"
    }

    task "resticrunner_server" {

      // home.andvari.net SSL
      template { 
        data = "{{ with nomadVar \"restic/docker\" }}{{ .ssh_key }}{{ end }}"
        destination = "secrets/docker-ssh-key"
        perms = "700"
      }
      template { 
        data = <<EOF
[docker]
sshkeyfile=/secrets/docker-ssh-key
repository={{ with nomadVar "restic/docker" }}{{ .repo }}{{ end }}
repo_password={{ with nomadVar "restic/docker" }}{{ .repo_pass }}{{ end }}
local_dir=/things/docker
restic_extra_args=--exclude-file=/things/docker/restic-excludes.txt
interval_hrs=24
EOF
        destination = "secrets/config.ini"
      }
      service {
	      name = "resticrunner-docker"
	      port = "resticrunner_http"
      }
      driver = "docker" 
      config {
        image = "gerrowadat/resticrunner:0.0.2"
        volumes = [
          "/things/docker:/things/docker:ro",
          # no keys here, just config and known_hosts.
          "/things/docker/restic/dotssh:/root/.ssh"
        ]
        labels {
          group = "resticrunner"
        }

        ports = ["resticrunner_http"]
      }
      env {
        RESTIC_JOBS = "docker"
        HTTP_PORT = "8901"
      }
    }

    network {
      port "resticrunner_http" {
        static = "8901"
      }
    }
  }
}
