#!/usr/bin/env python3
import base64
import datetime
import hashlib
import hmac
import http.server
import json
import os
import subprocess
import urllib.request


def log(msg):
    print(f"{datetime.datetime.now().isoformat()} {msg}", flush=True)


WEBHOOK_SECRET = os.environ["GITHUB_WEBHOOK_SECRET"].encode()
PORT = 9111

RELOAD_TARGETS = [
    "http://prometheus.service.home.consul:9090/-/reload",
    "http://prom-alertmanager.service.home.consul:9093/-/reload",
    "http://prom-blackbox-exporter.service.home.consul:9115/-/reload",
]

GRAFANA_ADMIN_USER = os.environ.get("GRAFANA_ADMIN_USER", "admin")
GRAFANA_ADMIN_PASSWORD = os.environ.get("GRAFANA_ADMIN_PASSWORD", "")

GRAFANA_RELOAD_TARGETS = [
    "http://grafana.service.home.consul:3000/api/admin/provisioning/datasources/reload",
    "http://grafana.service.home.consul:3000/api/admin/provisioning/dashboards/reload",
]


def verify_signature(body: bytes, signature_header: str) -> bool:
    if not signature_header or not signature_header.startswith("sha256="):
        return False
    expected = "sha256=" + hmac.new(WEBHOOK_SECRET, body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature_header)


def git_pull():
    log("Running: git -C /gitrepo pull")
    result = subprocess.run(
        ["git", "-C", "/gitrepo", "pull"],
        capture_output=True,
        text=True,
        timeout=60,
    )
    log(f"git pull stdout: {result.stdout.strip() or '(empty)'}")
    if result.stderr.strip():
        log(f"git pull stderr: {result.stderr.strip()}")
    log(f"git pull exit code: {result.returncode}")
    if result.returncode != 0:
        raise RuntimeError(f"git pull failed (exit {result.returncode}): {result.stderr}")
    return result.stdout


def touches_monitoring(payload):
    """Returns True if any prometheus/alertmanager/blackbox config files changed."""
    changed = []
    for commit in payload.get("commits", []):
        for key in ("added", "removed", "modified"):
            for path in commit.get(key, []):
                if path.startswith("monitoring/") and not path.startswith("monitoring/grafana/"):
                    changed.append(f"{key}: {path}")
    if changed:
        log(f"Monitoring files changed ({len(changed)}): {', '.join(changed)}")
    else:
        log("No prometheus/alertmanager/blackbox files changed — skipping prometheus reload")
    return bool(changed)


def touches_grafana_config(payload):
    """Returns True if any Grafana provisioning files changed."""
    changed = []
    for commit in payload.get("commits", []):
        for key in ("added", "removed", "modified"):
            for path in commit.get(key, []):
                if path.startswith("monitoring/grafana/"):
                    changed.append(f"{key}: {path}")
    if changed:
        log(f"Grafana config files changed ({len(changed)}): {', '.join(changed)}")
    else:
        log("No monitoring/grafana/ files changed — skipping grafana reload")
    return bool(changed)


def reload_services():
    for url in RELOAD_TARGETS:
        log(f"Sending POST /-/reload to {url}")
        req = urllib.request.Request(url, method="POST", data=b"")
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                if resp.status not in (200, 204):
                    raise RuntimeError(f"HTTP {resp.status}")
                log(f"  -> OK (HTTP {resp.status})")
        except Exception as e:
            raise RuntimeError(f"Reload failed for {url}: {e}")


def reload_grafana():
    if not GRAFANA_ADMIN_PASSWORD:
        raise RuntimeError("GRAFANA_ADMIN_PASSWORD not set — cannot reload Grafana provisioning")
    credentials = base64.b64encode(
        f"{GRAFANA_ADMIN_USER}:{GRAFANA_ADMIN_PASSWORD}".encode()
    ).decode()
    for url in GRAFANA_RELOAD_TARGETS:
        log(f"Sending POST to {url}")
        req = urllib.request.Request(url, method="POST", data=b"")
        req.add_header("Authorization", f"Basic {credentials}")
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                if resp.status not in (200, 204):
                    raise RuntimeError(f"HTTP {resp.status}")
                log(f"  -> OK (HTTP {resp.status})")
        except Exception as e:
            raise RuntimeError(f"Grafana reload failed for {url}: {e}")


class WebhookHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        log(format % args)

    def do_POST(self):
        client = f"{self.client_address[0]}:{self.client_address[1]}"
        log(f"--- incoming POST {self.path} from {client} ---")

        if self.path != "/webhooks/monitoring-reload":
            log(f"Unknown path {self.path!r}, returning 404")
            self.send_response(404)
            self.end_headers()
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)
        log(f"Body: {content_length} bytes")

        delivery = self.headers.get("X-GitHub-Delivery", "(none)")
        event = self.headers.get("X-GitHub-Event", "")
        signature = self.headers.get("X-Hub-Signature-256", "")
        log(f"X-GitHub-Delivery: {delivery}")
        log(f"X-GitHub-Event: {event!r}")
        log(f"X-Hub-Signature-256: {signature[:20]}..." if signature else "X-Hub-Signature-256: (missing)")

        if not verify_signature(body, signature):
            log("Signature verification FAILED — returning 401")
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b"Invalid signature")
            return
        log("Signature verified OK")

        if event != "push":
            log(f"Non-push event {event!r} — ignoring")
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f"Ignoring event: {event}".encode())
            return

        try:
            payload = json.loads(body)
        except json.JSONDecodeError as e:
            log(f"JSON parse error: {e}")
            self.send_response(400)
            self.end_headers()
            self.wfile.write(f"Invalid JSON: {e}".encode())
            return

        ref = payload.get("ref", "")
        repo = payload.get("repository", {}).get("full_name", "(unknown)")
        pusher = payload.get("pusher", {}).get("name", "(unknown)")
        commits = payload.get("commits", [])
        head_commit = payload.get("head_commit") or {}
        head_sha = head_commit.get("id", "")[:8]
        compare_url = payload.get("compare", "")

        log(f"repo={repo} ref={ref} pusher={pusher} commits={len(commits)} head={head_sha}")
        if compare_url:
            log(f"compare: {compare_url}")

        for i, commit in enumerate(commits):
            sha = commit.get("id", "")[:8]
            message = commit.get("message", "").splitlines()[0]
            added = len(commit.get("added", []))
            removed = len(commit.get("removed", []))
            modified = len(commit.get("modified", []))
            author = commit.get("author", {}).get("name", "(unknown)")
            log(f"  commit[{i}]: {sha} by {author} +{added}/-{removed}/~{modified} '{message}'")

        if ref != "refs/heads/main":
            log(f"Ref {ref!r} is not refs/heads/main — ignoring")
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f"Ignoring push to {ref}".encode())
            return

        log("Push is to main — processing")
        try:
            git_pull()
            if touches_monitoring(payload):
                log("Triggering reload of prometheus/alertmanager/blackbox")
                reload_services()
                log("All prometheus service reloads complete")
            if touches_grafana_config(payload):
                log("Triggering reload of Grafana provisioning")
                reload_grafana()
                log("Grafana provisioning reload complete")
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        except Exception as e:
            log(f"ERROR: {e}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode())

        log(f"--- done ---")


if __name__ == "__main__":
    log(f"homelab-webhook starting on :{PORT}")
    log(f"Reload targets: {RELOAD_TARGETS}")
    server = http.server.HTTPServer(("0.0.0.0", PORT), WebhookHandler)
    log(f"Listening on :{PORT}")
    server.serve_forever()
