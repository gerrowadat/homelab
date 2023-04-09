#!/bin/sh

nomad acl policy apply -description "Variable reader/writer" variable-admin variable-admin-policy.hcl

# Give the letsencrypt-to-nomad-vars job access to the nomad-tokens/variable-admin variable.
# you should populate the 'tok' key in there with a token that has access to the variable-admin policy.
nomad acl policy apply -namespace default -job letsencrypt-to-nomad-vars letsencrypt-sync-policy - <<EOF
namespace "default" {
  variables {
    path "nomad-tokens/variable-admin" {
      capabilities = ["read", "list"]
    }
  }
}
EOF

