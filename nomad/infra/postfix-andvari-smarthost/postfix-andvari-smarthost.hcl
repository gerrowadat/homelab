// Accept mail locally and queue/forward to mx.andvari.net
job "postfix-andvari-smarthost" {
  datacenters = ["home"]
  group "postfix-andvari-smarthost_servers" {
   
    task "postfix-andvari-smarthost_server" {
      service {
        name = "postfix-andvari-smarthost"
        port = "smtp"
      }
      driver = "docker" 
      config {
        image = "mwader/postfix-relay:latest"
        labels {
          group = "postfix-andvari-smarthost"
        }
        ports = ["smtp"]
      }
      resources {
        cpu = 1000
        memory = 512
     }
     env {
       POSTFIX_mydestination = "home.andvari.net"
       POSTFIX_relayhost = "mx.andvari.net"
       POSTFIX_mynetworks = "192.168.100.0/24,172.17.0.0/24"
     }
    }

    network {
      port "smtp" {
        static = "25"
      }
    }

  }
}
