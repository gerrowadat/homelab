job "haproxy" {
  datacenters = ["home"]
  group "haproxy_servers" {


    task "haproxy_server" {
      service {
        name = "haproxy"
	      port = "haproxy_main"
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
        ports = ["haproxy_main", "haproxy_freshrss"]
      }
    }

    network {
      mode = "host"
      port "haproxy_main" {
        static = "4567"
      }
      port "haproxy_freshrss" {
        static = "4568"
      }
    }
  }
}
