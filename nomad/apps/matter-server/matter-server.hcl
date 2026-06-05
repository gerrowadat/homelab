job "matter-server" {
  datacenters = ["home"]

  meta {
    gitops_managed = "true"
  }

  group "matter-server" {
    volume "matter-server" {
      type            = "csi"
      source          = "matter-server"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    task "matter-server" {
      driver = "docker"

      service {
        name = "matter-server"
        port = "ws"
        check {
          name     = "TCP"
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }

      template {
        data        = <<'EOF'
#!/bin/sh
# Find the interface used for outbound traffic (the LAN interface).
IFACE=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
if [ -z "$IFACE" ]; then
  # Fallback: first non-loopback interface with a link-local IPv6 address.
  IFACE=$(ip -o -6 addr show scope link | grep -v '^ *[0-9]*: lo' | awk 'NR==1{print $2}')
fi
echo "matter-server: using interface $IFACE"
exec python-matter-server --storage-path /data --primary-interface "$IFACE"
EOF
        destination = "local/start.sh"
        perms       = "0755"
      }

      config {
        image        = "ghcr.io/home-assistant-libs/python-matter-server:8.1.0"
        ports        = ["ws"]
        entrypoint   = ["/bin/sh", "/local/start.sh"]
        security_opt = ["apparmor=unconfined"]
      }

      volume_mount {
        volume      = "matter-server"
        destination = "/data"
      }

      resources {
        cpu        = 200
        memory     = 256
        memory_max = 512
      }
    }

    network {
      mode = "host"
      port "ws" { static = 5580 }
    }
  }
}
