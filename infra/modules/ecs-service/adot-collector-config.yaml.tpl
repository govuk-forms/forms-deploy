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
  resourcedetection/ecs:
    detectors: [ecs]
    timeout: 2s
    override: false
    ecs:
      resource_attributes:
        aws.ecs.cluster.arn:
          enabled: false
        aws.ecs.launchtype:
          enabled: false
        aws.ecs.task.family:
          enabled: false
        aws.ecs.task.revision:
          enabled: false
        cloud.account.id:
          enabled: false
        cloud.availability_zone:
          enabled: false
        cloud.platform:
          enabled: false
        cloud.provider:
          enabled: false
        cloud.region:
          enabled: false
  resource/env:
    attributes:
      - key: deployment.environment.name
        value: ${env_name}
        action: upsert

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
      processors: [resourcedetection/ecs, resource/env, batch/metrics]
      exporters: [otlphttp]
