job "resticrunner-localssd" {
  datacenters = ["home"]
  group "resticrunner-localssd_servers" {

    task "resticrunner-localssd-duckeason" {

      constraint {
        attribute = "${attr.unique.hostname}"
        value = "duckseason"
      }

      template { 
        data = "{{ with nomadVar \"nomad/jobs/resticrunner-localssd\" }}{{ .ssh_key }}{{ end }}"
        destination = "secrets/localssd-ssh-key"
        perms = "700"
      }
      template { 
        data = "{{ with nomadVar \"nomad/jobs/resticrunner-localssd\" }}{{ .ssh_config }}{{ end }}"
        destination = "local/ssh_config"
        perms = "700"
      }
      template { 
        data = "{{ with nomadVar \"nomad/jobs/resticrunner-localssd\" }}{{ .ssh_known_hosts }}{{ end }}"
        destination = "local/known_hosts"
        perms = "700"
      }
      template { 
        data = <<EOF
[duckseason_localssd]
sshkeyfile=/secrets/localssd-ssh-key
repository={{ with nomadVar "nomad/jobs/resticrunner-localssd" }}{{ .restic_sftp_uri }}{{ end }}:duckseason
repo_password={{ with nomadVar "nomad/jobs/resticrunner-localssd" }}{{ .restic_repo_pass }}{{ end }}
local_dir=/localssd
interval_hrs=24
ssh_extra_args=-F /local/ssh_config
EOF
        destination = "secrets/config.ini"
      }
      driver = "docker" 
      config {
        image = "gerrowadat/resticrunner:0.0.5"
        volumes = [
          "/localssd:/localssd:ro",
        ]
        labels {
          group = "restic"
        }

        ports = ["resticrunner_localssd_duckseason_http"]
      }
      env {
        RESTIC_JOBS = "duckseason_localssd"
        HTTP_PORT = "8902"
      }
    }

    network {
      port "resticrunner_localssd_duckseason_http" {
        static = "8902"
      }
    }
  }
}

