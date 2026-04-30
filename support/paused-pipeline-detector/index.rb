require_relative "./lib/notifier"
require_relative "./lib/paused_pipeline_detector"

require "aws-sdk-codepipeline"
require "aws-sdk-sns"

# rubocop:disable Lint/UnusedMethodArgument
def main(event:, context:)
  # rubocop:enable Lint/UnusedMethodArgument
  codepipeline = Aws::CodePipeline::Client.new
  sns = Aws::SNS::Client.new
  notifier = Notifier.new(sns, ENV["SLACK_SNS_TOPIC"], ENV["FORMS_AWS_ACCOUNT_NAME"])

  # This code is run on a schedule (see event bridge trigger in Terraform).
  # The threshold value here says the minimum amount of time in horus that any
  # given stage can be paused for before we get an alert, when the code runs.
  paused_duration_threshold_hours = 24

  PausedPipelineDetector
    .find_paused_pipelines(codepipeline, paused_duration_threshold_hours)
    .each do |paused_pipeline|
      longest_paused_stage = PausedPipelineDetector.longest_paused_stage(paused_pipeline.stage_states)

      notifier.notify_about_paused_pipeline(
        paused_pipeline.pipeline_name,
        longest_paused_stage.inbound_transition_state.last_changed_at,
        longest_paused_stage.inbound_transition_state.disabled_reason,
      )
    end
end
