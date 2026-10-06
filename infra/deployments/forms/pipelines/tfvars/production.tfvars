deploy-forms-product-page-container = {
  trigger_on_tag_patterns  = ["stg-*"]
  retag_image_on_success   = true
  retagging_sed_expression = "s/stg-\\(.*\\)/prod-\\1/" # "This was OK in production"
  apply_latest_tag         = true
  disable_end_to_end_tests = false
  pipeline_execution_mode  = "QUEUED"
}

deploy-forms-runner-container = {
  trigger_on_tag_patterns  = ["stg-*"]
  retag_image_on_success   = true
  retagging_sed_expression = "s/stg-\\(.*\\)/prod-\\1/" # "This was OK in production"
  apply_latest_tag         = true
  disable_end_to_end_tests = false
  pipeline_execution_mode  = "QUEUED"
}


deploy-forms-admin-container = {
  trigger_on_tag_patterns  = ["stg-*"]
  retag_image_on_success   = true
  retagging_sed_expression = "s/stg-\\(.*\\)/prod-\\1/" # "This was OK in production"
  apply_latest_tag         = true
  disable_end_to_end_tests = false
  pipeline_execution_mode  = "QUEUED"
}

apply-terraform = {
  pipeline_trigger         = "EVENT"
  git_source_branch        = null
  previous_stage_name      = "staging"
  disable_end_to_end_tests = false
  pipeline_execution_mode  = "QUEUED"
}

paused-pipeline-detection = {
  trigger_schedule_expression = "rate(12 hours)"
}
