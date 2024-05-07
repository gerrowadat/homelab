# Configs for restic backups.

This uses a couple of things:

   - [resticrunner](https://github.com/gerrowadat/nomad-homelab/tree/main/resticrunner)
   - The [nomad-conf](https://github.com/gerrowadat/nomad-homelab/tree/main/nomad-conf) tool for getting stuff in there.
       - `go install github.com/gerrowadat/nomad-homelab/nomad-conf@latest`

# Initial setup

Its assumed you're backing up via ssh, because that's what I do. Assume I do it.

  - Populate SSH stuff for the 'resticrunner'  job.
   - `nomad-conf upload ~/.ssh/config nomad/jobs/resticrunner:ssh_config`
   - `nomad-conf upload ~/.ssh/known_hosts nomad/jobs/resticrunner:ssh_known_hosts`
   - `nomad-conf upload ~/.ssh/id_rsa nomad/jobs/resticrunner:ssh_key`
   - `echo "sftp:user@host" | nomad-conf var put nomad/jobs/resticrunner:restic_sftp_uri`
   - `echo "myresticrepopassword" | nomad-conf var put nomad/jobs/resticrunner:restic_repo_pass`

  - Take a look at resticrunner.hcl and things should be working assuming you're using the above variables correctly.


# Setting up backups on a new host:
 - Add a task in resticruner.hcl with a config written by the template and the right volumes. Take a look at the existing things.

# Adding a new directory
 - Add a new resticrunner ini entry for each directory within the right task definition for your host.
