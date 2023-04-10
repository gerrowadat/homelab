job "haproxy" {
  datacenters = ["home"]
  group "haproxy_servers" {


    task "haproxy_server" {
      service {
        name = "haproxy"
	      port = "haproxy"
      }
      driver = "docker" 
      config {
        image = "haproxy:2.7"
        volumes = [
          "/things/homelab/nomad/infra/haproxy:/usr/local/etc/haproxy"
        ]
        labels {
          group = "haproxy"
        }
        ports = ["haproxy"]
      }
    }

    network {
      mode = "host"
      port "haproxy" {
        static = "4567"
      }
    }
  }
}
