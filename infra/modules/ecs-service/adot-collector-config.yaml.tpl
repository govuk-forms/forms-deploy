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
%{ if length(drop_spans) > 0 ~}
  filter/drop_spans:
    error_mode: ignore
    traces:
      span:
%{ for expr in drop_spans ~}
        - '${expr}'
%{ endfor ~}
%{ endif ~}
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
%{ if single_writer_meter_name != "" ~}
  # Metrics from the single writer meter are recorded by a scheduled job that runs once
  # across all tasks, so there is only ever one writer. They go through their own pipeline,
  # which leaves out the per-task and per-process resource attributes, so that each one is a
  # single series rather than a new series for each task that happened to run the job.
  filter/exclude_single_writer_metrics:
    error_mode: ignore
    metrics:
      metric:
        - 'instrumentation_scope.name == "${single_writer_meter_name}"'
  filter/include_single_writer_metrics:
    error_mode: ignore
    metrics:
      metric:
        - 'instrumentation_scope.name != "${single_writer_meter_name}"'
  resource/drop_process_identity:
    attributes:
      - pattern: '^(process|telemetry\.sdk)\.'
        action: delete
%{ endif ~}

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
      processors: [${length(drop_spans) > 0 ? "filter/drop_spans, " : ""}batch/traces]
      exporters: [awsxray]
    metrics:
      receivers: [otlp]
      processors: [${single_writer_meter_name != "" ? "filter/exclude_single_writer_metrics, " : ""}resourcedetection/ecs, resource/env, batch/metrics]
      exporters: [otlphttp]
%{ if single_writer_meter_name != "" ~}
    metrics/single_writer:
      receivers: [otlp]
      processors: [filter/include_single_writer_metrics, resource/drop_process_identity, resource/env, batch/metrics]
      exporters: [otlphttp]
%{ endif ~}
