// Allows nomad-botherer to list, read, and plan jobs in the default namespace.
// Note: Nomad's ACL model does not have a plan-only capability -- submit-job
// covers both planning and submitting. This token can technically submit jobs,
// but nomad-botherer only uses the plan API for drift detection.
namespace "default" {
  capabilities = ["list-jobs", "read-job", "submit-job"]
}
