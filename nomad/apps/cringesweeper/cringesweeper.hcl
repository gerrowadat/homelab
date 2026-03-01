job "cringesweeper" {
  datacenters = ["home"]
  group "cringesweeper_servers" {
    count = 1
    task "cringesweeper" {
      driver = "docker"
      config {
        image   = "ghcr.io/gerrowadat/cringesweeper:0.3.0"
        command = "/app/cringesweeper"
        args    = ["server", "--port=8080", "--platforms=bluesky,mastodon", "--max-post-age=60d", "--preserve-pinned", "--preserve-selflike", "--unlike-posts", "--unshare-reposts"]
      }
      template {
        data = <<EOH
{{- with nomadVar "nomad/jobs/cringesweeper" -}}
BLUESKY_USER={{ .bluesky_user }}
BLUESKY_PASSWORD={{ .bluesky_password }}
MASTODON_USER={{ .mastodon_user }}
MASTODON_INSTANCE={{ .mastodon_instance }}
MASTODON_ACCESS_TOKEN={{ .mastodon_access_token }}
{{- end -}}
EOH
        destination = "secrets/cringesweeper.env"
        env         = true
      }
    }
  }
}
