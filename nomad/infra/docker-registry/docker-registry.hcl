job "docker-registry" {
  datacenters = ["home"]
  group "registry_servers" {
    task "registry_server" {

      template { 
        data = "{{ with nomadVar \"ssl_certs/docker-registry_home_andvari_net\" }}{{ .privkey }}{{ end }}"
        destination = "secrets/docker-registry.home.andvari.net-privkey.pem"
        change_mode = "signal"
        change_signal = "SIGHUP"
        perms = 700
      }
      template { 
        data = "{{ with nomadVar \"ssl_certs/docker-registry_home_andvari_net\" }}{{ .chain }}{{ end }}"
        destination = "secrets/docker-registry.home.andvari.net-fullchain.pem"
        perms = 700
      }

      service {
        name = "docker-registry"
	      port = "registry"
      }
      driver = "docker" 
      config {
        image = "registry:2"
        volumes = [
          "/things/docker/docker-registry:/var/lib/registry",
        ]
        labels {
          group = "registry"
        }
        ports = ["registry"]
      }
      env {
        REGISTRY_HTTP_ADDR = "0.0.0.0:5000"
        REGISTRY_HTTP_TLS_CERTIFICATE = "/secrets/docker-registry.home.andvari.net-fullchain.pem"
        REGISTRY_HTTP_TLS_KEY = "/secrets/docker-registry.home.andvari.net-privkey.pem"
      }
    }
    network {
      mode = "host"
      port "registry" {
        static = "5000"
      }
    }
  }
}
