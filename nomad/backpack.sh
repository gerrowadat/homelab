#!/bin/bash

# This script takes a recently-bootstrapped Nomad cluster and rebuilds it to a usable state.

# Assumptions:
#  - All hosts have been ansiblised and are running nomad.
#  - You have NOMAD_TOKEN set to an admin token.
#  - You are running this on one of the nodes (i.e. you have all the required NFS mounts available).

# Things to do first
#
# - Edit infra/certbot/certbot.hcl and make sure it's constrained to run on your nfs server.
# - Same with infra/letsencrypt-to-nomad-vars/letsencrypt-to-nomad-vars.hcl


######### Nomad ACLs #########################

echo "Applying Nomad ACLs"

# Create a variable-admin policy we can generate tokens from.
nomad acl policy apply -description "Variable reader/writer" variable-admin acl/variable-admin-policy.hcl

VARIABLE_TOKEN=`nomad acl token create -name="variable reader/writer" -policy=variable-admin | grep "Secret ID" | cut -f4 -d' '`

# Store our new token where letsencrypt-to-nomad-vars can get it.
nomad var put nomad-tokens/variable-admin tok=${VARIABLE_TOKEN}

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

########### Infra nomad Jobs ##################

echo "Starting infra jobs..."

nomad job run infra/certbot/certbot.hcl

nomad job run infra/letsencrypt-to-nomad-vars/letsencrypt-to-nomad-vars.hcl

nomad job run infra/docker-registry/docker-registry.hcl

