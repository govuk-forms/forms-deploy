##
# Athena: the workgroup the Grafana data source runs its queries in, and the
# bucket their results are written to. Grafana reads results back from the
# bucket, so they only need to be kept for a short time.
##
locals {
  athena_results_bucket_name = "govuk-forms-${var.environment_name}-grafana-athena-results"
}

module "athena_results_bucket" {
  source = "../secure-bucket"

  name = local.athena_results_bucket_name
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = module.athena_results_bucket.name

  rule {
    id     = "expire-query-results"
    status = "Enabled"
    filter {}

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_athena_workgroup" "grafana" {
  name        = local.name
  description = "Queries run by the Grafana Athena data source"

  configuration {
    # Stops a query overriding the results location, encryption or scan limit
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = var.athena_bytes_scanned_cutoff_per_query

    result_configuration {
      output_location = "s3://${module.athena_results_bucket.name}/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}
