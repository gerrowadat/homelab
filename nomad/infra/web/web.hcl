job "web" {
  datacenters = ["home"]
  group "web_servers" {

    count = 1
    constraint {
      attribute = "${attr.unique.hostname}"
      value = "hedwig"
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

      // birbs.home.andvari.net SSL
      template { 
        data = "{{ with nomadVar \"ssl_certs/birbs_home_andvari_net\" }}{{ .privkey }}{{ end }}"
        destination = "secrets/birbs.home.andvari.net-privkey.pem"
        change_mode = "signal"
        change_signal = "SIGHUP"
        perms = 700
      }
      template { 
        data = "{{ with nomadVar \"ssl_certs/birbs_home_andvari_net\" }}{{ .chain }}{{ end }}"
        destination = "secrets/birbs.home.andvari.net-fullchain.pem"
        change_mode = "signal"
        change_signal = "SIGHUP"
        perms = 700
      }

      // drone.home.andvari.net SSL
      template { 
        data = "{{ with nomadVar \"ssl_certs/drone_home_andvari_net\" }}{{ .privkey }}{{ end }}"
        destination = "secrets/drone.home.andvari.net-privkey.pem"
        change_mode = "signal"
        change_signal = "SIGHUP"
        perms = 700
      }
      template { 
        data = "{{ with nomadVar \"ssl_certs/drone_home_andvari_net\" }}{{ .chain }}{{ end }}"
        destination = "secrets/drone.home.andvari.net-fullchain.pem"
        change_mode = "signal"
        change_signal = "SIGHUP"
        perms = 700
      }

      // nginx.cf
      template { 
        data = "{{ with nomadVar \"nomad/jobs/web\" }}{{ .nginx_cf }}{{ end }}"
        destination = "local/nginx.cf"
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
          upstream local-haproxy-drone {
            least_conn;
            server {{ env "NOMAD_ADDR_haproxy_drone" }};
          }
          upstream local-kubehttp {
            least_conn;
            server 192.168.100.240;
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
          //"/things/homelab/nomad/infra/web/default.conf:/etc/nginx/conf.d/default.conf",
          "local/nginx.cf:/etc/nginx/conf.d/default.conf",
          "/things/docker/ssl:/etc/letsencrypt",
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
      // haproxy.cfg
      template { 
        data = "{{ with nomadVar \"nomad/jobs/web\" }}{{ .haproxy_cfg }}{{ end }}"
        destination = "local/haproxy.cfg"
        change_mode = "signal"
        change_signal = "SIGHUP"
        perms = 744
      }
      driver = "docker"
      config {
        image = "haproxy:2.8"
        volumes = [
            // local/haproxy.cfg is populated from nomad var nomad/jobs/web:haproxy_cfg
            "local/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg"
        ]
        labels {
          group = "nginx_servers"
        }
        ports = ["haproxy_main", "haproxy_drone"]
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
      port "haproxy_drone" {
        static = "4568"
      }
    }
  }
}
