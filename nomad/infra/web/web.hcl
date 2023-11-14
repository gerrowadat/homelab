job "web" {
  datacenters = ["home"]
  group "web_servers" {

    // Only run on core machines.
    count = 3
    constraint {
      attribute = "${attr.cpu.arch}"
      operator = "="
      value = "amd64"
    }

    task "nginx_server" {

      // home.andvari.net SSL
      template { 
        data = "{{ with nomadVar \"ssl_certs/home_andvari_net\" }}{{ .privkey }}{{ end }}"
        destination = "secrets/home.andvari.net-privkey.pem"
        change_mode = "signal"
        change_signal = "SIGHUP"
        perms = 700
      }
      template { 
        data = "{{ with nomadVar \"ssl_certs/home_andvari_net\" }}{{ .chain }}{{ end }}"
        destination = "secrets/home.andvari.net-fullchain.pem"
        change_mode = "signal"
        change_signal = "SIGHUP"
        perms = 700
      }


      template { 
        data = <<EOH
          upstream local-haproxy-main {
            least_conn;
            server {{ env "NOMAD_ADDR_haproxy_main" }};
          }
        EOH
        destination = "local/local-haproxy-upstreams.conf"
        change_mode = "signal"
        change_signal = "SIGHUP"
        perms = 700
      }
      service {
	      name = "nginx"
	      port = "http"
      }
      driver = "docker" 
      config {
        image = "nginx"
        volumes = [
          "/things/homelab/nomad/infra/web/default.conf:/etc/nginx/conf.d/default.conf",
          "/things/docker/ssl:/etc/letsencrypt",
          "/things/docker/web/htpasswd:/etc/nginx/htpasswd"
        ]
        labels {
          group = "nginx"
        }
        ports = ["http", "https"]
      }
      resources {
        cpu = 200
        memory = 200
     }
    }

    task "haproxy_server" {
      service {
        name = "haproxy"
        port = "haproxy_main"
      }
      driver = "docker"
      config {
        image = "haproxy:2.7"
        volumes = [
          "/things/homelab/nomad/infra/web:/usr/local/etc/haproxy"
        ]
        labels {
          group = "nginx_servers"
        }
        ports = ["haproxy_main"]
      }
    }


    network {
      port "http" {
        static = "80"
      }
      port "https" {
        static = "443"
      }
      port "haproxy_main" {
        static = "4567"
      }
    }
  }
}
