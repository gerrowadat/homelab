job "git-pull-gitrepo" {
  datacenters = ["home"]

  type = "batch"
  periodic {
    cron = "*/5 * * * * *"
  }

  group "git-pull-gitrepo_servers" {

    volume "gitrepo" {
      type = "csi"
      source = "gitrepo"
      read_only = false
      attachment_mode = "file-system"
      access_mode = "multi-node-multi-writer"
    }

    // docker image is only built for x86 et. al.
    constraint {
      attribute = "${attr.cpu.arch}"
      operator = "="
      value = "amd64"
    }

    task "git-pull-gitrepo_worker" {
      driver = "docker" 
      config {
        image = "binfalse/git-pull"
      }
      volume_mount {
        volume = "gitrepo"
        destination = "/git-project"
      }
    }
  }
}
