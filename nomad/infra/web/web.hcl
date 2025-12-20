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

      // nginx.cf
      template { 
        data = "{{ with nomadVar \"nomad/jobs/web\" }}{{ .nginx_cf }}{{ end }}"
        destination = "local/nginx.cf"
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

    network {
      port "http" {
        static = "80"
      }
      port "https" {
        static = "443"
      }
    }
  }
}
