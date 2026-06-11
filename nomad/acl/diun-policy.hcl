// Allows Diun's Nomad provider to discover images from running Docker tasks.
// It lists jobs and reads job/allocation details; nothing is submitted or
// mutated, so list-jobs + read-job is sufficient.
namespace "default" {
  capabilities = ["list-jobs", "read-job"]
}
