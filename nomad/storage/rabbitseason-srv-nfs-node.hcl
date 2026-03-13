job "rabbitseason-srv-nfs-node" {
  datacenters = ["home"]
  type        = "system"

  group "node" {
    task "node" {
      driver = "docker"

      config {
        image = "registry.gitlab.com/rocketduck/csi-plugin-nfs:1.1.0"

        args = [
          "--type=node",
          "--node-id=${attr.unique.hostname}",
          "--nfs-server=rabbitseason:/srv",
          "--mount-options=defaults",
        ]

        network_mode = "host" # required so the mount works even after stopping the container

        privileged = true
      }

      csi_plugin {
        id        = "rabbitseason-srv-nfs"
        type      = "node"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 500
        memory = 256
      }

    }
  }
}
