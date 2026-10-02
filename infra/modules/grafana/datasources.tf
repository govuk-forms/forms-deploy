# Data sources are provisioned from a file Grafana reads at start up. The
# file is rendered here and written into the container by its command, see
# ecs.tf. All of them authenticate with the task role.
locals {
  aws_datasource_json_data = {
    authType      = "default"
    defaultRegion = data.aws_region.current.region
  }

  datasources = [
    {
      name      = "CloudWatch"
      uid       = "cloudwatch"
      type      = "cloudwatch"
      access    = "proxy"
      isDefault = true
      editable  = false
      jsonData  = local.aws_datasource_json_data
    },
    {
      name     = "X-Ray"
      uid      = "xray"
      type     = "grafana-x-ray-datasource"
      access   = "proxy"
      editable = false
      jsonData = local.aws_datasource_json_data
    },
    {
      # Queries metrics ingested through the CloudWatch OTLP endpoint with
      # PromQL. The Amazon Managed Service for Prometheus plugin is pointed
      # at CloudWatch's Prometheus-compatible API rather than a workspace,
      # so requests must be signed for the "monitoring" service, see
      # https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-PromQL-Grafana.html
      name     = "CloudWatch PromQL"
      uid      = "cloudwatch-promql"
      type     = "grafana-amazonprometheus-datasource"
      access   = "proxy"
      url      = "https://monitoring.${data.aws_region.current.region}.amazonaws.com"
      editable = false
      jsonData = {
        httpMethod    = "POST"
        sigV4Auth     = true
        sigV4AuthType = "default"
        sigV4Region   = data.aws_region.current.region
        sigv4Service  = "monitoring"
      }
    }
  ]

  datasources_yaml = yamlencode({
    apiVersion  = 1
    datasources = local.datasources
  })
}
