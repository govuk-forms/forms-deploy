# A single project is shared by the app deploy pipelines. All of the
# apps store their assets in the same bucket: every file is fingerprinted
# with a content hash, so names cannot collide.
module "sync_assets" {
  source                     = "../../../modules/code-build-build"
  project_name               = "sync_assets_${var.environment_name}"
  project_description        = "Sync assets from a container image to the assets bucket"
  environment                = var.environment_name
  artifact_store_arn         = module.artifact_bucket.arn
  buildspec                  = file("${path.root}/buildspecs/sync-assets/sync-assets.yml")
  log_group_name             = "codebuild/sync_assets_${var.environment_name}"
  codebuild_service_role_arn = data.aws_iam_role.deployer_role.arn

  environment_variables = {
    ASSETS_BUCKET      = data.terraform_remote_state.forms_environment.outputs.assets_bucket_name
    CONTAINER_REGISTRY = var.container_registry
  }
}
