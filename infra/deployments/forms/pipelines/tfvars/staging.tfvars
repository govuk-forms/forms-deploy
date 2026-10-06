deploy-forms-product-page-container = {
  trigger_on_tag_patterns  = ["merged-*"]
  retag_image_on_success   = true
  retagging_sed_expression = "s/merged-\\(.*\\)/stg-\\1/" # "This was OK in staging"
  apply_latest_tag         = false
  disable_end_to_end_tests = false
  pipeline_execution_mode  = "SUPERSEDED"
}

deploy-forms-runner-container = {
  trigger_on_tag_patterns  = ["merged-*"]
  retag_image_on_success   = true
  retagging_sed_expression = "s/merged-\\(.*\\)/stg-\\1/" # "This was OK in staging"
  apply_latest_tag         = false
  disable_end_to_end_tests = false
  pipeline_execution_mode  = "SUPERSEDED"
}


deploy-forms-admin-container = {
  trigger_on_tag_patterns  = ["merged-*"]
  retag_image_on_success   = true
  retagging_sed_expression = "s/merged-\\(.*\\)/stg-\\1/" # "This was OK in staging"
  apply_latest_tag         = false
  disable_end_to_end_tests = false
  pipeline_execution_mode  = "SUPERSEDED"
}

apply-terraform = {
  pipeline_trigger         = "GIT"
  git_source_branch        = "main"
  previous_stage_name      = null
  disable_end_to_end_tests = false
  pipeline_execution_mode  = "SUPERSEDED"
}

paused-pipeline-detection = {
  trigger_schedule_expression = "rate(12 hours)"
}
