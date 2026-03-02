# nomad/cron

Periodic batch jobs (Nomad `type = "batch"` with `periodic` blocks).

| Job | What it does |
|---|---|
| `git-pull-homelab` | Pulls the latest homelab repo to a local path on the cluster |
| `pull-gitrepo` | Generic git pull job, parameterised by repo |
