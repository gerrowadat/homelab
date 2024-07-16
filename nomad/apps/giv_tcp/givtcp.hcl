job "givtcp" {
  datacenters = ["home"]
  priority = 100
  group "givtcp_servers" {

    constraint {
      attribute = "${attr.unique.hostname}"
      value = "hedwig"
    }
    task "givtcp_server" {
      driver = "docker" 
      config {
        image = "britkat/giv_tcp-ma:2.4.0"
        labels {
          group = "givtcp"
        }
        ports = ["givtcp_web", "givtcp_rest"]
      }
     env {
      NUMINVERTORS = 1                # Set this to the number of Inverters in your setup, then replicate the next two lines for each inverter (changing the last number of the ENV)
      INVERTOR_IP_1 = "192.168.110.114"                # Set this to the IP address of your Inverter on your local network
      INVERTOR_AIO_1 = "True"         # Set this to true if you have an AIO
      INVERTOR_AC_1 = "False"           # Set this to true if you have an AC on old firmware and don't have the new registers
      NUMBATTERIES_1 = 0              # Number of battery modules installed and connected to the above inverter. Set to 0 for AIO.
      INVERTOR_NAME_1 = "AIO"              # Friendly display name for the inverter
      MQTT_OUTPUT = "False"              # "True" if you want to publish your data to MQTT, "False" otherwise
      CACHELOCATION = "/config/GivTCP"  # Location of cache data, this folder can be mapped to a persistence storage outside the container
      TZ = "Europe/Dublin"             # Set to your Timezone

      LOG_LEVEL = "Info"               # Level of logs to be reported: "Error", "Info" or "Debug"
      PRINT_RAW = "True"               # If True this will publish all inverter data unprocessed as well as standard data
      SELF_RUN = "True"                # If True the container will self-run and connect and publish data. If "False" the you will need to trigger externally via REST
      SELF_RUN_LOOP_TIMER = 5         # Wait time between every read command to the inverter
      QUEUE_RETRIES = 2               # The number of calls to the inverter when trying to set a register. A higher number improves the chance of inverter writes succeeding
      INFLUX_OUTPUT = "False"           # "True" if you want to publish your data to InfluxDB, "False" otherwise
      PYTHONPATH = "/app"
      WEB_DASH = "True"                # Enable the web dashboard
      WEB_DASH_PORT = 6346            # Port to serve the web dashboard on. Should be the same as the private port (above), not the container port
      DATASMOOTHER = "medium"           # Set the data smoothing to most aggressive setting (High, medium, low, none)
     }
    }
    network {
      port "givtcp_rest" {
        static = "6345"
      }
      port "givtcp_web" {
        static = 6346
      }
    }

  }
}
