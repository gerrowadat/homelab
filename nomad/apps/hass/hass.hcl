job "hass" {
  datacenters = ["home"]
  group "hass_servers" {

    constraint {
      attribute = "${attr.unique.hostname}"
      value = "hedwig"
    }
    task "hass_server" {
      service {
	      name = "hass"
	      port = "hass"
      }
      driver = "docker" 
      config {
        image = "homeassistant/home-assistant:2022.12"
        volumes = [
          "/localssd/hass:/config",
          "/etc/localtime:/etc/localtime",
        ]
        labels {
          group = "hass"
        }
        ports = ["hass"]
        dns_servers = ["192.168.100.250", "192.168.100.251", "192.168.100.253"]
      }
     env {
       PYTHONUSERBASE = "/config/deps"
       PYTHONPATH = "/config/deps/python3.8/site-packages"
     }
    }
    network {
      port "hass" {
        static = "8123"
      }
    }

  }
}
