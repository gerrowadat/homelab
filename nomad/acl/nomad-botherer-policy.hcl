// Allows nomad-botherer to list, read, plan, and mutate jobs in the default namespace.
// csi-list-volume, csi-read-volume, and csi-mount-volume are required when submitting
// jobs that claim CSI volumes -- Nomad validates and claims volumes at registration time.
//
// The variables{} block grants read access to all job-level variables. Nomad
// enforces an anti-privilege-escalation check at job registration: a token that
// submits a job whose templates read a Nomad variable (via nomadVar) must itself
// have read access to that variable path. Without this, submitting any job that
// reads its nomad/jobs/<jobname> secrets fails with a 403. Since botherer can
// reconcile any gitops-managed job, it needs read on the whole nomad/jobs/* tree.
namespace "default" {
  capabilities = [
    "list-jobs",
    "read-job",
    "submit-job",
    "csi-list-volume",
    "csi-read-volume",
    "csi-mount-volume",
  ]

  variables {
    path "nomad/jobs/*" {
      capabilities = ["read"]
    }
  }
}
