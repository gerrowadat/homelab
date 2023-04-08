// A policy to read/write any variables.
namespace "*" {
  policy = "write"

  # this policy can write, read, or destroy any variable in any namespace
  variables {
    path "*" {
      capabilities = ["write", "read", "destroy"]
    }
  }
}
