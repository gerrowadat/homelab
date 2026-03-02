// Allows Traefik's Nomad provider to read the service catalog for routing.
// Read access on the namespace is sufficient -- Traefik only needs to list
// and read services, not submit jobs or access variables.
namespace "default" {
  policy = "read"
}
