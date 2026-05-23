job "otel-collector" {
  datacenters = ["home"]
  type        = "system"

  group "otel-collector" {
    network {
      mode = "host"
      port "otlp_grpc" { static = 4317 }
      port "otlp_http" { static = 4318 }
      port "metrics"   { static = 8889 }
    }

    task "otel-collector" {
      driver = "docker"
      # UID 0 required to read /var/lib/docker/containers (root:root 700).
      # The right fix is default ACLs on the host via Ansible + group_add here.
      user   = "0"

      config {
        image = "otel/opentelemetry-collector-contrib:0.152.0"
        args  = ["--config=/local/otel-collector.yml"]
        ports = ["otlp_grpc", "otlp_http", "metrics"]
        volumes = [
          "/var/lib/docker/containers:/hostlog/containers:ro",
          "/var/run/docker.sock:/var/run/docker.sock:ro",
        ]
      }

      template {
        destination = "local/otel-collector.yml"
        data        = <<EOH
extensions:
  # Watches the Docker daemon for container start/stop events. Used by
  # receiver_creator to dynamically create a filelog instance per container,
  # with that container's labels (Nomad job/task/alloc) injected as resource
  # attributes at discovery time.
  docker_observer:
    endpoint: unix:///var/run/docker.sock

receivers:
  receiver_creator:
    watch_observers: [docker_observer]
    receivers:
      filelog:
        rule: type == "container"
        config:
          include:
            - /hostlog/containers/`container_id`/`container_id`-json.log
          include_file_path: true
          operators:
            # Docker wraps each log line in JSON: {"log":"...", "stream":"stdout", "time":"..."}
            - type: json_parser
              timestamp:
                parse_from: attributes.time
                layout_type: gotime
                layout: '2006-01-02T15:04:05.999999999Z07:00'
            - type: move
              from: attributes.log
              to: body
            - type: move
              from: attributes.stream
              to: attributes["log.iostream"]
          resource:
            nomad.job:      '`labels["com.hashicorp.nomad.job_name"]`'
            nomad.task:     '`labels["com.hashicorp.nomad.task_name"]`'
            nomad.group:    '`labels["com.hashicorp.nomad.task_group_name"]`'
            nomad.alloc_id: '`labels["com.hashicorp.nomad.alloc_id"]`'
            container.id:   '`container_id`'

  otlp:
    protocols:
      grpc:
        endpoint: "0.0.0.0:4317"
      http:
        endpoint: "0.0.0.0:4318"

processors:
  batch:
    timeout: 5s

  resourcedetection/system:
    detectors: [system]
    system:
      hostname_sources: [os]

  # Promote Nomad labels and host.name from resource attributes to log record
  # attributes so VictoriaLogs indexes them as queryable fields.
  transform/record_attrs:
    log_statements:
      - context: log
        statements:
          - set(attributes["nomad.job"],      resource.attributes["nomad.job"])
          - set(attributes["nomad.task"],     resource.attributes["nomad.task"])
          - set(attributes["nomad.group"],    resource.attributes["nomad.group"])
          - set(attributes["nomad.alloc_id"], resource.attributes["nomad.alloc_id"])
          - set(attributes["host.name"],      resource.attributes["host.name"])

exporters:
  otlphttp/logs:
    endpoint: "http://logs.service.home.consul:9428/insert/opentelemetry"
    tls:
      insecure: true

  # Expose any OTLP metrics received from apps for future Prometheus scraping.
  prometheus:
    endpoint: "0.0.0.0:8889"

service:
  extensions: [docker_observer]
  pipelines:
    logs:
      receivers: [receiver_creator, otlp]
      processors: [batch, resourcedetection/system, transform/record_attrs]
      exporters: [otlphttp/logs]
    metrics:
      receivers: [otlp]
      processors: [batch, resourcedetection/system]
      exporters: [prometheus]
EOH
      }

      service {
        name = "otel-collector"
        port = "otlp_grpc"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
