# cringesweeper

[Cringesweeper](https://github.com/gerrowadat/cringesweeper) — automatically
deletes old posts from Bluesky and Mastodon, keeping the timeline clean.

Runs as a background daemon (no web UI). Configured to sweep posts older than
60 days, preserving pinned posts, self-liked posts, and undoing reposts.

## Nomad variable

`nomad/jobs/cringesweeper` must contain:

| Key | Description |
|---|---|
| `bluesky_user` | Bluesky handle |
| `bluesky_password` | Bluesky app password |
| `mastodon_user` | Mastodon username |
| `mastodon_instance` | Mastodon instance URL |
| `mastodon_access_token` | Mastodon API access token |

## Deployment

```bash
nomad job run nomad/apps/cringesweeper/cringesweeper.hcl
```
