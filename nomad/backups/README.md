Configs for restic backups.

This uses a couple of things:

   - [resticrunner](https://github.com/gerrowadat/nomad-homelab/tree/main/resticrunner)
   - The stuff in [//homelab/backups/](https://github.com/gerrowadat/homelab/tree/main/backups) to set things up.

How to add a new backup:

 - Figure out the remote repo (I use sftp to offsite). Generate an ssh keypair, ideally just for this purpose.
     - Run 'restic init' first, all this runner does is run 'restic backup'.
 - Run [load_backup_config.sh](https://github.com/gerrowadat/homelab/blob/main/backups/load_backup_config.sh)
   - Feed it a config name (can be anything), then your repo location and password.
 - Create your new .hcl file here:
    - Should be very similar to the others.
    - mae sure to update RESTIC_JOBS in the env{} block, and point the bind mount for `/root/.ssh` to a place with a suitable ssh_config.
    - you'll eaither need to log into the container once to accept the remote host key, or pre-populate a known_hosts in the bind mount, or set `StrictHostKeyChecking no` in ssh_config if you like to live dangerously.
  - Start your job (it won't work because it doesn't have access to the restic/ vars)
  - Run [grant_job_access_to_restic_keys.sh](https://github.com/gerrowadat/homelab/blob/main/backups/grant_job_access_to_restic_keys.sh) thusly:
    - `./grant_job_access_to_restic_keys.sh jobname configname`
    - Your job should then come up. Go look at the logs an see what went wrong.
  - Have fun!

TODO:

  - Monitoring.
