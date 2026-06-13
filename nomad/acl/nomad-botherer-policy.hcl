// Allows nomad-botherer to list, read, plan, and mutate jobs in the default namespace.
// csi-list-volume, csi-read-volume, and csi-mount-volume are required when submitting
// jobs that claim CSI volumes -- Nomad validates and claims volumes at registration time.
namespace "default" {
  capabilities = [
    "list-jobs",
    "read-job",
    "submit-job",
    "csi-list-volume",
    "csi-read-volume",
    "csi-mount-volume",
  ]
}
