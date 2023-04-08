// Runs docker-registry on port 5000, which is a standard private registry for pushing stuff to.
// Also runs docker-registry-proxy on port 5001, which is just for proxying.

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

    task "registry_proxy" {
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
        name = "docker-registry-proxy"
	      port = "registry-proxy"
      }
      driver = "docker" 
      config {
        image = "registry:2"
        volumes = [
          "/things/docker/docker-registry-proxy:/var/lib/registry",
        ]
        labels {
          group = "registry"
        }
        ports = ["registry-proxy"]
      }
      env {
        REGISTRY_HTTP_ADDR = "0.0.0.0:5001"
        REGISTRY_HTTP_TLS_CERTIFICATE = "/secrets/docker-registry.home.andvari.net-fullchain.pem"
        REGISTRY_HTTP_TLS_KEY = "/secrets/docker-registry.home.andvari.net-privkey.pem"
        REGISTRY_PROXY_REMOTEURL = "https://registry-1.docker.io"
      }
    }

    network {
      mode = "host"
      port "registry" {
        static = "5000"
      }
      port "registry-proxy" {
        static = "5001"
      }
    }
  }
}
