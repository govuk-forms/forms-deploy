##
# This file hard codes environment names which should receive end-to-end tests.
# At first glance, this ought not to be necessary, or desirable.
#
# However, the end-to-end tests container building CodeBuild job has an extra
# step within the buildspec which runs the tests in the container against the
# staging environment, for which it needs credentials from the
# 'automated-test-parameters' module.
#
# https://github.com/govuk-forms/forms-e2e-tests/blob/main/bin/dockerfile_test.sh
#
# This exists because it currently isn't possible for us to test the code before
# it gets packaged.
##
locals {
  environments_with_e2e = ["dev", "staging", "production"]
}

module "forms_e2e_tests" {
  source                  = "../../../modules/e2e-image-pipeline"
  codestar_connection_arn = var.codestar_connection_arn
  ecr_repository_url      = data.terraform_remote_state.deploy_ecr.outputs.e2e_tests_ecr_repository_url
}

module "automated_test_parameters" {
  for_each = toset(local.environments_with_e2e)

  source           = "../../../modules/automated-test-parameters"
  environment_name = each.key
}
