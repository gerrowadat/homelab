# GitOps Setup Suggestion

## Current State

The repo already has a partial GitOps loop:

- **homelab-webhook** (Nomad job at `nomad/infra/homelab-webhook/`) receives GitHub push
  webhooks, runs `git pull` on the `gitrepo` CSI volume, and POSTs `/-/reload` to
  Prometheus, Alertmanager, Blackbox Exporter, and Grafana when their config files change.
- **nomad-botherer** (second task group in the same job) watches for drift between HCL
  files in the repo and live Nomad job state, and surfaces diffs at `/diffs` — but does
  not act on them.
- **GitHub Actions** validates monitoring configs on PRs and pushes to `main`.

The gap: changes to Nomad job HCL files, Terraform, or Ansible require manual operator
intervention (`nomad job run`, `terraform apply`, `ansible-playbook`). The repo is the
source of truth in intent but not in practice.

---

## Proposed Architecture

The goal is to close that gap in three phases, each independently useful, without
replacing what already works.

```
         Push / PR
              │
              ▼
    ┌──────────────────┐
    │  GitHub Actions  │  ← CI: validate + plan (all layers)
    └────────┬─────────┘
             │ merge to main
             ▼
    ┌──────────────────┐
    │  Self-hosted     │  ← CD: runs inside the cluster
    │  Actions runner  │      direct access to Nomad/Consul APIs
    └────────┬─────────┘
             │
     ┌───────┴────────┐
     ▼                ▼
 Nomad jobs       Terraform
 (job run)        (tf apply)
                      │
                      ▼
               Grafana Cloud SM
               (synthetic monitoring)
```

Ansible is out-of-band by nature (push-based host provisioning) and is handled
separately in Phase 3.

---

## Phase 1 — Better CI (validate everything, not just monitoring)

**Add to `.github/workflows/`:**

### 1a. Nomad HCL validation

```yaml
# .github/workflows/nomad-validate.yml
on:
  pull_request:
    paths: ["nomad/**"]
  push:
    branches: [main]
    paths: ["nomad/**"]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-nomad@v1
        with:
          version: "1.9.x"   # pin to cluster version
      - name: Validate all job files
        run: |
          find nomad -name "*.hcl" | while read f; do
            echo "Validating $f"
            nomad job validate "$f"
          done
```

`nomad job validate` does full HCL parse and semantic checks without a live cluster.
It catches type errors, unknown fields, and constraint mistakes that `hcl` parsers alone
would miss.

### 1b. Nomad job plan (diff) on PRs

For PRs that touch Nomad job files, run `nomad job plan` against the live cluster and
post the diff as a PR comment. This requires network access to the Nomad API — see the
self-hosted runner in Phase 2. Skip for now or gate behind a label.

### 1c. Terraform validation

```yaml
# .github/workflows/terraform-validate.yml
on:
  pull_request:
    paths: ["terraform/**"]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform -chdir=terraform init -backend=false
      - run: terraform -chdir=terraform validate
      - run: terraform -chdir=terraform fmt -check -recursive
```

### 1d. Ansible lint

```yaml
# .github/workflows/ansible-lint.yml
on:
  pull_request:
    paths: ["ansible/**"]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ansible/ansible-lint-action@v6
        with:
          path: ansible/
```

---

## Phase 2 — Self-hosted GitHub Actions Runner (the key enabler)

A self-hosted runner deployed as a Nomad job gives CI/CD pipelines direct network
access to the Nomad API (`:4646`), Consul (`:8500`), and all internal services — without
exposing any of those ports externally.

### Why self-hosted, not GitHub-hosted?

GitHub-hosted runners have no route to `192.168.100.0/24`. Options to bridge the gap
are: a reverse tunnel (e.g. via the existing Newt/Pangolin setup), or a self-hosted
runner. A runner on the cluster is simpler, more reliable, and keeps secrets off
GitHub-hosted infrastructure.

### Runner Nomad job

```hcl
# nomad/infra/actions-runner/actions-runner.hcl
job "actions-runner" {
  datacenters = ["home"]
  type        = "service"

  constraint {
    attribute = "${attr.cpu.arch}"
    value     = "amd64"
  }

  group "runner" {
    count = 1

    task "runner" {
      driver = "docker"

      config {
        image   = "myoung34/github-runner:latest"
        volumes = ["/var/run/docker.sock:/var/run/docker.sock"]
      }

      template {
        data        = <<EOF
RUNNER_SCOPE=repo
REPO_URL=https://github.com/gerrowadat/homelab
ACCESS_TOKEN={{with nomadVar "nomad/jobs/actions-runner"}}{{.github_pat}}{{end}}
RUNNER_NAME=homelab-nomad
LABELS=homelab,nomad
EPHEMERAL=false
EOF
        destination = "secrets/env"
        env         = true
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
```

**Nomad variable required:**
```
nomad var put nomad/jobs/actions-runner \
  github_pat=<fine-grained PAT with repo Actions:read+write>
```

The fine-grained PAT needs: `Actions: Read and Write`, `Metadata: Read`.

### Targeting the runner in workflows

```yaml
runs-on: [self-hosted, homelab]
```

Any job using this label runs on the cluster node and can reach Nomad/Consul directly.

---

## Phase 2b — Automatic Nomad Job Deployment on Merge

Once the runner is in place, extend `homelab-webhook` or add a new workflow:

```yaml
# .github/workflows/nomad-deploy.yml
on:
  push:
    branches: [main]
    paths: ["nomad/**"]

jobs:
  deploy:
    runs-on: [self-hosted, homelab]
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Find changed job files
        id: changed
        run: |
          git diff --name-only HEAD~1 HEAD -- 'nomad/**/*.hcl' \
            | grep -v 'storage/volumes' \
            > changed_jobs.txt
          cat changed_jobs.txt

      - name: Deploy changed jobs
        env:
          NOMAD_ADDR: http://hedwig:4646
          NOMAD_TOKEN: ${{ secrets.NOMAD_TOKEN }}
        run: |
          while read job; do
            echo "==> Deploying $job"
            nomad job run "$job"
          done < changed_jobs.txt
```

**Key design decisions:**

- Only deploy files that changed in the merge commit — not all jobs on every push.
- Skip `storage/volumes/` — volume registrations should stay manual (they're
  infrastructure, not application, and registering an existing volume is a no-op but
  re-registering a wrong volume definition can destroy data).
- The Nomad token is stored as a GitHub Actions secret (encrypted at rest, never
  logged). Scope it to a Nomad ACL policy that can `submit-job` but not manage
  variables or ACL tokens.
- If a deployment fails, the workflow fails and GitHub notifies the committer. The
  previous allocation keeps running (Nomad's deployment strategy handles rollback for
  service jobs with `update` stanzas).

### ACL policy for the runner token

```hcl
# nomad/acl/gitops-deployer.hcl
namespace "default" {
  policy       = "write"
  capabilities = ["submit-job", "read-job", "list-jobs"]
}
```

```bash
nomad acl policy apply gitops-deployer nomad/acl/gitops-deployer.hcl
nomad acl token create -name=gitops-deployer -policy=gitops-deployer \
  | grep 'Secret ID' | awk '{print $4}'
# Store the token as GitHub Actions secret: NOMAD_TOKEN
```

---

## Phase 3 — Terraform GitOps via Atlantis

For Terraform (currently `terraform/` — Grafana Cloud Synthetic Monitoring), Atlantis
provides a PR-based workflow: `plan` on PR open/update, `apply` on PR merge after
approval.

### Atlantis as a Nomad job

```hcl
# nomad/infra/atlantis/atlantis.hcl
job "atlantis" {
  datacenters = ["home"]
  type        = "service"

  constraint {
    attribute = "${attr.cpu.arch}"
    value     = "amd64"
  }

  group "atlantis" {
    count = 1

    task "atlantis" {
      driver = "docker"

      config {
        image = "ghcr.io/runatlantis/atlantis:latest"
        args  = ["server"]
      }

      template {
        data        = <<EOF
ATLANTIS_GH_USER=<bot-account>
ATLANTIS_GH_TOKEN={{with nomadVar "nomad/jobs/atlantis"}}{{.github_token}}{{end}}
ATLANTIS_GH_WEBHOOK_SECRET={{with nomadVar "nomad/jobs/atlantis"}}{{.webhook_secret}}{{end}}
ATLANTIS_REPO_ALLOWLIST=github.com/gerrowadat/homelab
ATLANTIS_PORT=4141
ATLANTIS_ATLANTIS_URL=https://atlantis.home.andvari.net
# Terraform credentials for Grafana Cloud provider
GRAFANA_CLOUD_API_KEY={{with nomadVar "nomad/jobs/atlantis"}}{{.grafana_api_key}}{{end}}
EOF
        destination = "secrets/env"
        env         = true
      }

      service {
        name = "atlantis"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.atlantis.rule=Host(`atlantis.home.andvari.net`)",
          "traefik.http.routers.atlantis.tls=true",
          "traefik.http.routers.atlantis.tls.certresolver=le",
          # No internal-only — GitHub needs to POST webhooks here
        ]

        check {
          type     = "http"
          path     = "/healthz"
          interval = "30s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
```

Add `atlantis.home.andvari.net` to the DNS zone and point the GitHub repo webhook at it.

An `atlantis.yaml` in the repo root scopes which directories Atlantis manages:

```yaml
# atlantis.yaml
version: 3
projects:
  - name: grafana-sm
    dir: terraform
    workflow: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
```

This keeps Atlantis limited to `terraform/` and does not give it access to Nomad job
files (those are handled by the Actions runner).

---

## Phase 4 — Ansible (optional, lower priority)

Ansible is fundamentally pull-unfriendly (it's push-based and requires SSH access to
hosts). Options:

1. **Status quo** — run `ansible-playbook` manually from a workstation. CI lints, humans
   deploy. This is fine for infrastructure that changes rarely.

2. **Scheduled re-apply via Actions** — a cron workflow that runs `ansible-playbook` on
   the self-hosted runner (which has cluster network access) on a schedule. Catches
   drift from manual changes. Risky if a bad playbook auto-applies to all hosts.

3. **AWX / Semaphore** — a Nomad-hosted Ansible UI with webhook triggers. More overhead
   than benefit for a homelab.

Recommendation: keep Ansible manual for now. Add CI lint (Phase 1d) and document the
playbook in `playbook.md`. Revisit if host provisioning becomes frequent.

---

## Summary of Changes by Phase

| Phase | What changes | Effort | Risk |
|-------|-------------|--------|------|
| 1a | Add `nomad-validate.yml` workflow | Low | None |
| 1c | Add `terraform-validate.yml` workflow | Low | None |
| 1d | Add `ansible-lint.yml` workflow | Low | None |
| 2 | Nomad job for self-hosted Actions runner | Medium | Low |
| 2b | `nomad-deploy.yml` workflow + ACL policy | Medium | Medium |
| 3 | Atlantis Nomad job + DNS entry + repo webhook | High | Low |
| 4 | Ansible automation | High | High |

Phases 1 and 2 together give the most value for the least risk: every PR gets
validation, every merge to `main` auto-deploys changed Nomad jobs.

---

## What This Does Not Replace

- **Nomad variables** — still created manually before first deploy. The deployer token
  does not have permission to write variables.
- **CSI volume registration** — still manual (`nomad volume register`). Volume changes
  need human review before apply.
- **Secret rotation** — Nomad variables are the secret store; rotation is still manual.
- **New service DNS entries** — BIND9 zone files in `dns/` are deployed by the existing
  `homelab-webhook` config-reload path (they go via the gitrepo volume and DNS job
  reload), so those are already covered once the webhook handles DNS changes.

---

## Further Reading

- [Nomad job validate docs](https://developer.hashicorp.com/nomad/docs/commands/job/validate)
- [GitHub Actions self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners)
- [myoung34/github-runner Docker image](https://github.com/myoung34/docker-github-actions-runner)
- [Atlantis](https://www.runatlantis.io/)
- [Nomad ACL](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control)
