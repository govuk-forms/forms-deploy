deploy-forms-product-page-container = {
  trigger_on_tag_patterns  = ["stg-*"]
  retag_image_on_success   = false
  retagging_sed_expression = ""
  apply_latest_tag         = false
  disable_end_to_end_tests = true
  pipeline_execution_mode  = "QUEUED"
}

deploy-forms-runner-container = {
  trigger_on_tag_patterns  = ["stg-*"]
  retag_image_on_success   = false
  retagging_sed_expression = ""
  apply_latest_tag         = false
  disable_end_to_end_tests = true
  pipeline_execution_mode  = "QUEUED"
}


deploy-forms-admin-container = {
  trigger_on_tag_patterns  = ["stg-*"]
  retag_image_on_success   = false
  retagging_sed_expression = ""
  apply_latest_tag         = false
  disable_end_to_end_tests = true
  pipeline_execution_mode  = "QUEUED"
}

apply-terraform = {
  pipeline_trigger         = "EVENT"
  git_source_branch        = null
  previous_stage_name      = "staging"
  disable_end_to_end_tests = true
}

paused-pipeline-detection = {
  trigger_schedule_expression = "rate(48 hours)"
}
