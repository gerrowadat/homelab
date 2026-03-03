job "monitoring-webhook" {
  datacenters = ["home"]
  type        = "service"

  group "monitoring-webhook_servers" {

    volume "gitrepo" {
      type            = "csi"
      source          = "gitrepo"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    // docker image is only built for x86 et. al.
    constraint {
      attribute = "${attr.cpu.arch}"
      operator  = "="
      value     = "amd64"
    }

    task "monitoring-webhook_server" {
      driver = "docker"
      user   = "nobody"

      config {
        image   = "python:3.12-alpine"
        command = "/bin/sh"
        args    = ["-c", "apk add --no-cache git && python /local/webhook.py"]
        ports   = ["monitoring-webhook"]
        dns_search_domains = ["home.andvari.net"]
      }

      volume_mount {
        volume      = "gitrepo"
        destination = "/gitrepo"
      }

      template {
        destination = "secrets/env"
        env         = true
        data        = <<EOF
GITHUB_WEBHOOK_SECRET={{ with nomadVar "nomad/jobs/monitoring-webhook" }}{{ .github_webhook_secret }}{{ end }}
EOF
      }

      template {
        destination = "local/webhook.py"
        data        = <<PYEOF
#!/usr/bin/env python3
import hashlib
import hmac
import http.server
import json
import os
import subprocess
import urllib.request

WEBHOOK_SECRET = os.environ["GITHUB_WEBHOOK_SECRET"].encode()
PORT = 9111

RELOAD_TARGETS = [
    "http://prometheus.service.home.consul:9090/-/reload",
    "http://prom-alertmanager.service.home.consul:9093/-/reload",
    "http://prom-blackbox-exporter.service.home.consul:9115/-/reload",
]


def verify_signature(body: bytes, signature_header: str) -> bool:
    if not signature_header or not signature_header.startswith("sha256="):
        return False
    expected = "sha256=" + hmac.new(WEBHOOK_SECRET, body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature_header)


def git_pull():
    result = subprocess.run(
        ["git", "-C", "/gitrepo", "pull"],
        capture_output=True,
        text=True,
        timeout=60,
    )
    if result.returncode != 0:
        raise RuntimeError(f"git pull failed: {result.stderr}")
    return result.stdout


def reload_services():
    for url in RELOAD_TARGETS:
        req = urllib.request.Request(url, method="POST", data=b"")
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status not in (200, 204):
                raise RuntimeError(f"Reload failed for {url}: HTTP {resp.status}")


class WebhookHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(format % args, flush=True)

    def do_POST(self):
        if self.path != "/webhooks/monitoring-reload":
            self.send_response(404)
            self.end_headers()
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        signature = self.headers.get("X-Hub-Signature-256", "")
        if not verify_signature(body, signature):
            print("Invalid signature", flush=True)
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b"Invalid signature")
            return

        event = self.headers.get("X-GitHub-Event", "")
        if event != "push":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f"Ignoring event: {event}".encode())
            return

        try:
            payload = json.loads(body)
        except json.JSONDecodeError as e:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(f"Invalid JSON: {e}".encode())
            return

        ref = payload.get("ref", "")
        if ref != "refs/heads/main":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f"Ignoring push to {ref}".encode())
            return

        try:
            out = git_pull()
            print(f"git pull: {out}", flush=True)
            reload_services()
            print("Reloaded all monitoring services", flush=True)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        except Exception as e:
            print(f"Error: {e}", flush=True)
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode())


if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", PORT), WebhookHandler)
    print(f"Listening on port {PORT}", flush=True)
    server.serve_forever()
PYEOF
      }

      service {
        name = "monitoring-webhook"
        port = "monitoring-webhook"
        check {
          name     = "TCP health check"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    network {
      mode = "host"
      port "monitoring-webhook" {
        static = "9111"
      }
    }
  }
}
