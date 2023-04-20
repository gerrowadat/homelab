#!/bin/bash

# This script takes a recently-bootstrapped Nomad cluster and rebuilds it to a usable state.
# I mean, I say it does, but you're probably not going to get good results for just running it.
# Think of it as a readable playbook moreseo than a real rebuild. It's never been used, for a start.

# Assumptions:
#  - All hosts have been ansiblised and are running nomad.
#  - You have NOMAD_TOKEN set to an admin token.
#  - You are running this on one of the nodes (i.e. you have all the required NFS mounts available).

# Things to do first
#
# - Mae sure you're happy with ansible/inventory.yml and that the hosts are up and etc.
# - Edit infra/certbot/certbot.hcl and make sure it's constrained to run on your nfs server.
# - Same with infra/letsencrypt-to-nomad-vars/letsencrypt-to-nomad-vars.hcl


echo "Installing host-level services."

# Get configurations, including our zone files, from github.
git clone https://github.com/gerrowadat/homelab.git /things/homelab

# Install DNS servers.
ansible-playbook -i ansible/inventory.yml ansible/site-dns.yml


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

# Generate/renew SSL certificates (some jobs need them).
nomad job run nomad/infra/certbot/certbot.hcl

# Start syncing SSL certs to nomad (any jobs like the registry or web servers son't start without these).
nomad job run nomad/infra/letsencrypt-to-nomad-vars/letsencrypt-to-nomad-vars.hcl

# Registry and registry proxy.
nomad job run nomad/infra/docker-registry/docker-registry.hcl

# This makes *.service.nomad start resolving corrently (or indeed, at all).
nomad job run nomad/infra/nomad-dns-exporter/nomad-dns-exporter.hcl

# Makes email delivery work (for a few things, including alerts!)
nomad job run nomad/infra/postfix-andvari-smarthost/postfix-andvari-smarthost.hcl

# Bring up web services. No backends yet, gimme a minute.
nomad job run nomad/infra/web/web.hcl

echo "Starting periodic tasks..."

nomad job run nomad/cron/git-pull-homelab.hcl

echo "Scheduling backups..."

nomad job run nomad/backups/resticrunner-docker.hcl

echo "Starting Monitoring services..."

nomad job run nomad/monitoring/prom-blackbox-exporter.hcl
nomad job run nomad/monitoring/prom-consul-exporter.hcl
nomad job run nomad/monitoring/prom-alertmanager.hcl
nomad job run nomad/monitoring/prometheus.hcl
nomad job run nomad/monitoring/grafana.hcl

