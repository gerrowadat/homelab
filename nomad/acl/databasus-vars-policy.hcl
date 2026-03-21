// Grants the Databasus job's workload identity read access to the postgres
// and mysql admin credentials, which live outside the default
// nomad/jobs/databasus path that workload identities can read automatically.
//
// Apply and bind with:
//   nomad acl policy apply -description "Databasus variable access" \
//     databasus-vars nomad/acl/databasus-vars-policy.hcl
//   nomad acl binding-rule create \
//     -auth-method=nomad-workloads \
//     -bind-type=policy \
//     -bind-name=databasus-vars \
//     -selector='value.nomad_job_id == "databasus"'
namespace "default" {
  variables {
    path "nomad/jobs/postgres" {
      capabilities = ["read"]
    }
    path "nomad/jobs/mysql" {
      capabilities = ["read"]
    }
  }
}
