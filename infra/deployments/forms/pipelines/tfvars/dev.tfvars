deploy-forms-product-page-container = {
  trigger_on_tag_patterns = ["dev-*", "prod-*"] # Dev pipeline should deploy from known-good production versions, and also allow for dev versions

  # Don't re-tag at the end. A successful run in dev should not trigger a path to production.
  # That is triggered by a merge to main in the relevant repository
  retag_image_on_success   = false
  retagging_sed_expression = ""
  apply_latest_tag         = false
  disable_end_to_end_tests = false
  pipeline_execution_mode  = "SUPERSEDED"
}

deploy-forms-runner-container = {
  trigger_on_tag_patterns = ["dev-*", "prod-*"] # Dev pipeline should deploy from known-good production versions, and also allow for dev versions

  # Don't re-tag at the end. A successful run in dev should not trigger a path to production.
  # That is triggered by a merge to main in the relevant repository
  retag_image_on_success   = false
  retagging_sed_expression = ""
  apply_latest_tag         = false
  disable_end_to_end_tests = false
  pipeline_execution_mode  = "SUPERSEDED"
}


deploy-forms-admin-container = {
  trigger_on_tag_patterns = ["dev-*", "prod-*"] # Dev pipeline should deploy from known-good production versions, and also allow for dev versions

  # Don't re-tag at the end. A successful run in dev should not trigger a path to production.
  # That is triggered by a merge to main in the relevant repository
  retag_image_on_success   = false
  retagging_sed_expression = ""
  apply_latest_tag         = false
  disable_end_to_end_tests = false
  pipeline_execution_mode  = "SUPERSEDED"
}

apply-terraform = {
  pipeline_trigger         = "MANUAL"
  git_source_branch        = "poc-pipelines-in-environments"
  previous_stage_name      = ""
  disable_end_to_end_tests = false
  pipeline_execution_mode  = "SUPERSEDED"
}

paused-pipeline-detection = {
  trigger_schedule_expression = "rate(48 hours)"
}
