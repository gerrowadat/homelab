// Grants the Traefik job's workload identity read access to cloud_dns_key,
// which lives outside the default nomad/jobs/traefik path that workload
// identities can read automatically.
//
// Apply and bind with:
//   nomad acl policy apply -description "Traefik variable access" \
//     traefik-vars nomad/acl/traefik-vars-policy.hcl
//   nomad acl binding-rule create \
//     -auth-method=nomad-workloads \
//     -bind-type=policy \
//     -bind-name=traefik-vars \
//     -selector='value.nomad_job_id == "traefik"'
namespace "default" {
  variables {
    path "cloud_dns_key" {
      capabilities = ["read"]
    }
  }
}
