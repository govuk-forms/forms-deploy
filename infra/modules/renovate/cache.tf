# The package cache (lookups and release notes, which take minutes to fetch for
# busy repos) is archived by CodeBuild. The repository cache is Renovate's own
# objects under repository-cache/.
module "cache_bucket" {
  source = "../secure-bucket"

  name                   = "govuk-forms-renovate-cache-${local.aws_account_id}"
  versioning_enabled     = false
  access_logging_enabled = false
}
