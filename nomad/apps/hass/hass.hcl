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
        image = "homeassistant/home-assistant:2026.2.3"
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
       # Home Assistant installs user Python packages (HACS integrations etc.) into
       # /config/deps, which is on the bind-mounted local SSD. This makes them
       # persist across container restarts without modifying the image.
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
