job "hass" {
  datacenters = ["home"]
  priority = 100
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
        image = "homeassistant/home-assistant:2023.11.3"
        volumes = [
          "/localssd/hass:/config",
          "/etc/localtime:/etc/localtime",
        ]
        labels {
          group = "hass"
        }
        ports = ["hass"]
      }
     env {
       PYTHONUSERBASE = "/config/deps"
       PYTHONPATH = "/config/deps/python3.8/site-packages"
     }
     resources {
       memory = 2048
     }
    }
    network {
      port "hass" {
        static = "8123"
      }
    }

  }
}
