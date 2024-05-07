job "resticrunner" {
  datacenters = ["home"]
  group "resticrunner-duckseason" {

    constraint {
      attribute = "${attr.unique.hostname}"
      value = "duckseason"
    }

    task "resticrunner-duckseason" {
      template { 
        data = "{{ with nomadVar \"nomad/jobs/resticrunner\" }}{{ .ssh_key }}{{ end }}"
        destination = "secrets/localssd-ssh-key"
        perms = "700"
      }
      template { 
        data = "{{ with nomadVar \"nomad/jobs/resticrunner\" }}{{ .ssh_config }}{{ end }}"
        destination = "local/ssh_config"
        perms = "700"
      }
      template { 
        data = "{{ with nomadVar \"nomad/jobs/resticrunner\" }}{{ .ssh_known_hosts }}{{ end }}"
        destination = "local/known_hosts"
        perms = "700"
      }
      template { 
        data = <<EOF
[duckseason_localssd]
sshkeyfile=/secrets/localssd-ssh-key
repository={{ with nomadVar "nomad/jobs/resticrunner" }}{{ .restic_sftp_uri }}{{ end }}:duckseason
repo_password={{ with nomadVar "nomad/jobs/resticrunner" }}{{ .restic_repo_pass }}{{ end }}
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

        ports = ["resticrunner_http"]
      }
      env {
        RESTIC_JOBS = "duckseason_localssd"
        HTTP_PORT = "8902"
      }
    }
    network {
      port "resticrunner_http" {
        static = "8902"
      }
    }
  } 

  group "resticrunner-hedwig" {
    constraint {
        attribute = "${attr.unique.hostname}"
        value = "hedwig"
    }
    task "resticrunner-hedwig" {
      template { 
        data = "{{ with nomadVar \"nomad/jobs/resticrunner\" }}{{ .ssh_key }}{{ end }}"
        destination = "secrets/localssd-ssh-key"
        perms = "700"
      }
      template { 
        data = "{{ with nomadVar \"nomad/jobs/resticrunner\" }}{{ .ssh_config }}{{ end }}"
        destination = "local/ssh_config"
        perms = "700"
      }
      template { 
        data = "{{ with nomadVar \"nomad/jobs/resticrunner\" }}{{ .ssh_known_hosts }}{{ end }}"
        destination = "local/known_hosts"
        perms = "700"
      }
      template { 
        data = <<EOF
[hedwig_localssd]
sshkeyfile=/secrets/localssd-ssh-key
repository={{ with nomadVar "nomad/jobs/resticrunner" }}{{ .restic_sftp_uri }}{{ end }}:hedwig
repo_password={{ with nomadVar "nomad/jobs/resticrunner" }}{{ .restic_repo_pass }}{{ end }}
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

        ports = ["resticrunner_http"]
      }
      env {
        RESTIC_JOBS = "hedwig_localssd"
        HTTP_PORT = "8902"
      }
    }
    network {
      port "resticrunner_http" {
        static = "8902"
      }
    }
  }
}
