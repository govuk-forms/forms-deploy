extensions:
  health_check:
  sigv4auth:
    service: monitoring
    region: ${aws_region}

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  awsxray:
    endpoint: 0.0.0.0:2000
    transport: udp

processors:
  batch/traces:
    timeout: 1s
    send_batch_size: 50
  batch/metrics:
    timeout: 10s

exporters:
  awsxray:
  otlphttp:
    tls:
      insecure: false
    metrics_endpoint: https://monitoring.${aws_region}.amazonaws.com/v1/metrics
    auth:
      authenticator: sigv4auth

service:
  extensions: [health_check, sigv4auth]
  pipelines:
    traces:
      receivers: [otlp, awsxray]
      processors: [batch/traces]
      exporters: [awsxray]
    metrics:
      receivers: [otlp]
      processors: [batch/metrics]
      exporters: [otlphttp]
