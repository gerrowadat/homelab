job "resticrunner" {
  datacenters = ["home"]
  priority = 100
  group "resticrunner-duckseason" {

    constraint {
      attribute = "${attr.unique.hostname}"
      value = "duckseason"
    }

    task "resticrunner-duckseason" {
      template { 
        data = "{{ with nomadVar \"nomad/jobs/resticrunner\" }}{{ .ssh_key }}{{ end }}"
        destination = "secrets/ssh_key"
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
        data = "{{ with nomadVar \"nomad/jobs/resticrunner\" }}{{ .restic_excludes }}{{ end }}"
        destination = "local/restic_excludes"
        perms = "700"
      }
      template { 
        data = <<EOF
[duckseason_localssd]
sshkeyfile=/secrets/ssh_key
repository={{ with nomadVar "nomad/jobs/resticrunner" }}{{ .restic_sftp_uri }}{{ end }}:duckseason
repo_password={{ with nomadVar "nomad/jobs/resticrunner" }}{{ .restic_repo_pass }}{{ end }}
local_dir=/localssd
interval_hrs=24
ssh_extra_args=-F /local/ssh_config

[duckseason_docker]
sshkeyfile=/secrets/ssh_key
repository={{ with nomadVar "nomad/jobs/resticrunner" }}{{ .restic_sftp_uri }}{{ end }}:duckseason
repo_password={{ with nomadVar "nomad/jobs/resticrunner" }}{{ .restic_repo_pass }}{{ end }}
local_dir=/export/things/docker
interval_hrs=24
ssh_extra_args=-F /local/ssh_config
restic_extra_args=--exclude-file=/local/restic_excludes

EOF
        destination = "secrets/config.ini"
      }
      driver = "docker" 
      resources {
        memory = 1024
      }
      config {
        image = "gerrowadat/resticrunner:0.0.5"
        volumes = [
          "/localssd:/localssd:ro",
          "/export/things/docker:/export/things/docker:ro",
        ]
        labels {
          group = "restic"
        }

        ports = ["resticrunner_http"]
      }
      env {
        RESTIC_JOBS = "duckseason_localssd,duckseason_docker"
        HTTP_PORT = "8902"
        GOGC = 20
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
        destination = "secrets/ssh_key"
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
sshkeyfile=/secrets/ssh_key
repository={{ with nomadVar "nomad/jobs/resticrunner" }}{{ .restic_sftp_uri }}{{ end }}:hedwig
repo_password={{ with nomadVar "nomad/jobs/resticrunner" }}{{ .restic_repo_pass }}{{ end }}
local_dir=/localssd
interval_hrs=24
ssh_extra_args=-F /local/ssh_config
EOF
        destination = "secrets/config.ini"
      }
      resources {
        memory = 1024
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
        GOGC = 20
      }
    }
    network {
      port "resticrunner_http" {
        static = "8902"
      }
    }
  }
}
