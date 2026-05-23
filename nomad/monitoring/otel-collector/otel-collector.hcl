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
        image = "otel/opentelemetry-collector-contrib:0.123.0"
        args  = ["--config=/local/otel-collector.yml"]
        ports = ["otlp_grpc", "otlp_http", "metrics"]
        volumes = [
          "/var/lib/docker/containers:/hostlog/containers:ro",
        ]
      }

      template {
        destination = "local/otel-collector.yml"
        data        = <<EOH
receivers:
  filelog:
    include:
      - /hostlog/containers/*/*.log
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
      - type: regex_parser
        regex: '/hostlog/containers/(?P<container_id>[a-f0-9]+)'
        parse_from: attributes["log.file.path"]
        parse_to: attributes
      - type: move
        from: attributes.stream
        to: attributes["log.iostream"]
      # Set host.name as a record attribute (not resource attribute) so VictoriaLogs
      # stores it as a queryable field. Uses Consul Template to query the local node name.
      - type: add
        field: attributes["host.name"]
        value: '{{ with node }}{{ .Node.Node }}{{ end }}'

  otlp:
    protocols:
      grpc:
        endpoint: "0.0.0.0:4317"
      http:
        endpoint: "0.0.0.0:4318"

processors:
  batch:
    timeout: 5s

  # Detects host.name from the OS hostname; applied to OTLP-pushed logs and metrics.
  # For filelog records, host.name is set as a record attribute via the add operator above.
  resourcedetection/system:
    detectors: [system]
    system:
      hostname_sources: [os]

exporters:
  otlphttp/logs:
    endpoint: "http://logs.service.home.consul:9428/insert/opentelemetry"
    tls:
      insecure: true

  # Expose any OTLP metrics received from apps for future Prometheus scraping.
  prometheus:
    endpoint: "0.0.0.0:8889"

service:
  pipelines:
    logs:
      receivers: [filelog, otlp]
      processors: [batch, resourcedetection/system]
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
