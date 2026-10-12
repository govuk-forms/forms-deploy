resource "aws_s3tables_table_bucket" "forms_analytics" {
  name = local.table_bucket_name
}

resource "aws_s3tables_namespace" "forms" {
  namespace        = local.namespace_name
  table_bucket_arn = aws_s3tables_table_bucket.forms_analytics.arn
}

# The table is deliberately unpartitioned: at our data volumes Iceberg's
# per-file column statistics prune time-range queries well enough, and an
# unpartitioned table can be fully managed here (the provider cannot yet set a
# partition spec, https://github.com/hashicorp/terraform-provider-aws/issues/46494).
resource "aws_s3tables_table" "submission_events" {
  name             = local.table_name
  namespace        = aws_s3tables_namespace.forms.namespace
  table_bucket_arn = aws_s3tables_table_bucket.forms_analytics.arn
  format           = "ICEBERG"

  metadata {
    iceberg {
      schema {
        field {
          name     = "submitted_at"
          type     = "timestamp"
          required = true
        }
        field {
          name = "form_id"
          type = "string"
        }
        field {
          name = "form_name"
          type = "string"
        }
        field {
          name = "preview"
          type = "boolean"
        }
      }
    }
  }

  # Destroying or replacing the table deletes its data, and any change to
  # metadata forces a replacement. Make schema changes outside Terraform or
  # migrate the data first.
  lifecycle {
    prevent_destroy = true
  }
}
