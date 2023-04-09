// deprecated, bind now gets installed via ansible.
//
job "bind" {
  // run everywhere
  type = "system"
  datacenters = ["home"]
  group "bind_servers" {

    constraint {
      attribute = "${attr.unique.hostname}"
      operator = "set_contains_any"
      value = "hedwig,rabbitseason,duckseason"
    }

    task "copy-bind-dir-to-local" {
      lifecycle {
        hook = "prestart"
        sidecar = false
      }
      driver = "raw_exec"
      config {
        command = "/usr/bin/rsync"
        args = ["-carv", "--delete", "/mnt/docker/bind/", "/local/bind/"]
      }
    }


    task "bind_server" {
      service {
	      name = "bind"
	      port = "dns"
      }
      driver = "docker" 
      config {
        #image = "${attr.kernel.name}" == "arm64" ? "mjkaye/bind9-alpine:latest-arm64" : "mjkaye/bind9-alpine:latest"
        image = "mjkaye/bind9-alpine:latest"
        volumes = [
          "/local/bind:/etc/bind"
        ]
        labels {
          group = "bind"
        }
        ports = ["dns"]
        # use outside DNS servers so we can actually bootstrap the jobs.
        dns_servers = ["8.8.8.8", "8.8.4.4"]
      }
      resources {
        cpu = 200
        memory = 200
     }
    }
    network {
      port "dns" {
        static = "53"
      }
    }
  }
}
