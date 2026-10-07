# Integrates S3 Tables with AWS analytics services (Athena, Firehose, etc.) by
# federating all S3 table buckets in the account into the Glue Data Catalog.
# This is an account+region singleton: the name must be "s3tablescatalog" and
# it covers every table bucket in the account, not just the one in this module.
# Access control is IAM-based (IAM_ALLOWED_PRINCIPALS), so consumers need IAM
# permissions only, no Lake Formation grants.
resource "aws_glue_catalog" "s3tablescatalog" {
  name = "s3tablescatalog"

  federated_catalog {
    connection_name = "aws:s3tables"
    identifier      = "arn:aws:s3tables:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:bucket/*"
  }

  create_database_default_permissions {
    permissions = ["ALL"]
    principal {
      data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
    }
  }

  create_table_default_permissions {
    permissions = ["ALL"]
    principal {
      data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
    }
  }

  allow_full_table_external_data_access = "True"
}
