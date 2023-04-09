job "git-pull-homelab" {
  datacenters = ["home"]

  type = "batch"
  periodic {
    cron = "*/5 * * * * *"
  }




  group "git-pull-homelab_servers" {

    // docker image is only built for x86 et. al.
    constraint {
      attribute = "${attr.cpu.arch}"
      operator = "="
      value = "amd64"
    }

    task "git-pull-homelab_worker" {
      driver = "docker" 
      config {
        image = "binfalse/git-pull"
        volumes = [
          "/things/homelab:/git-project"
        ]
        labels {
          group = "git-pull-homelab"
        }
      }
    }
  }
}
