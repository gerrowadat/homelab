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
//
// The plugin{} block grants read on the CSI plugin catalog. Registering a job
// that mounts a CSI volume is gated by AllowCSIMount, which requires BOTH the
// namespace csi-mount-volume capability AND plugin read -- csi-mount-volume
// alone is not enough and the submit fails with a 403 (e.g. kutt, which mounts
// the "kutt" CSI volume). Verified against the live cluster: with csi-mount-volume
// and the variables grant but no plugin read, register is denied; adding plugin
// read lets it through.
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

plugin {
  policy = "read"
}
