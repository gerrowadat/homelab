client {
  enabled = true

  # Prefer IPv4 when fingerprinting interface addresses. Without this, a node
  # with an IPv6 (e.g. a ULA fdxx::/8) address on its default interface can
  # register host-network services in Consul with that IPv6 address, which
  # IPv4-only consumers (newt, Traefik backends, scrape targets) can't reach.
  # Added in Nomad 1.9.0. Requires a nomad restart to take effect; services
  # re-register with the IPv4 address on their next registration.
  preferred_address_family = "ipv4"
}
