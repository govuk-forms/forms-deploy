require "aws-sdk-codepipeline"
require "aws-sdk-codepipeline/types"

class DevelopmentAWSSDKFactory
  # @return [Aws::CodePipeline::Client]
  # @param [string] role_arn
  def self.new_code_pipeline(role_arn)
    case role_arn
    when "arn:aws:iam::711966560482:role/codepipeline-readonly"
      deploy_env_client
    when "arn:aws:iam::498160065950:role/codepipeline-readonly"
      development_env_client
    when "arn:aws:iam::443944947292:role/codepipeline-readonly"
      production_env_client
    when "arn:aws:iam::972536609845:role/codepipeline-readonly"
      staging_env_client
    else
      raise "Unknown role arn. Consider adding it to the development fixtures."
    end
  end

  def self.deploy_env_client
    stub_all_as_passing(
      Aws::CodePipeline::Client.new(stub_responses: true),
      %w[
        deploy-pipeline-visualiser
        forms-runner-image-builder
        forms-product-page-image-builder
        forms-admin-image-builder
        e2e-image
      ],
    )
  end

  def self.development_env_client
    stub_all_as_passing(
      Aws::CodePipeline::Client.new(stub_responses: true),
      %w[apply-forms-terraform-dev deploy-forms-product-page-container-dev deploy-forms-runner-container-dev],
    )
  end

  def self.production_env_client
    client = stub_all_as_passing(
      Aws::CodePipeline::Client.new(stub_responses: true),
      %w[apply-forms-terraform-production],
    )

    stub_get_pipeline_state(client) do |pipeline_name|
      Aws::CodePipeline::Types::GetPipelineStateOutput.new(
        pipeline_name:,
        created: Time.now,
        updated: Time.now,
        pipeline_version: 2,
        stage_states: [
          Aws::CodePipeline::Types::StageState.new(
            stage_name: "stage_1",
            latest_execution: Aws::CodePipeline::Types::StageExecution.new(
              pipeline_execution_id: "execution-1",
              status: "Succeeded",
            ),
            inbound_transition_state: Aws::CodePipeline::Types::TransitionState.new(
              enabled: true,
            ),
          ),
          Aws::CodePipeline::Types::StageState.new(
            stage_name: "stage_2",
            latest_execution: Aws::CodePipeline::Types::StageExecution.new(
              pipeline_execution_id: "execution-1",
              status: "Failed",
            ),
            inbound_transition_state: Aws::CodePipeline::Types::TransitionState.new(
              enabled: true,
            ),
            action_states: [
              Aws::CodePipeline::Types::ActionState.new(
                action_name: "action-1",
                latest_execution: Aws::CodePipeline::Types::ActionExecution.new(
                  status: "Failed",
                  summary: "Build terminated with state: FAILED. Phase: BUILD, Code: COMMAND_EXECUTION_ERROR, Message: Error while executing command: foobar foo bar",
                ),
              ),
            ],
          ),
          Aws::CodePipeline::Types::StageState.new(
            stage_name: "stage_3",
            latest_execution: Aws::CodePipeline::Types::StageExecution.new(
              pipeline_execution_id: "execution-1",
              status: "Failed",
            ),
            inbound_transition_state: Aws::CodePipeline::Types::TransitionState.new(
              enabled: false,
              disabled_reason: "Paused while we debug",
              last_changed_at: Time.now - (1 * 60 * 60), # 1 hour ago,
            ),
            action_states: [
              Aws::CodePipeline::Types::ActionState.new(
                action_name: "action-1",
                latest_execution: Aws::CodePipeline::Types::ActionExecution.new(
                  status: "Failed",
                  summary: "Summary error message",
                  error_details: Aws::CodePipeline::Types::ErrorDetails.new(
                    code: "JobFailed",
                    message: "Error message from error details; build terminated with state: FAILED. Phase: BUILD.",
                  ),
                ),
              ),
            ],
          ),
          Aws::CodePipeline::Types::StageState.new(
            stage_name: "stage_4",
            latest_execution: Aws::CodePipeline::Types::StageExecution.new(
              pipeline_execution_id: "execution-2",
              status: "Succeeded",
            ),
            inbound_transition_state: Aws::CodePipeline::Types::TransitionState.new(
              enabled: true,
            ),
          ),
        ],
      )
    end

    stub_all_with_status(
      client,
      %w[deploy-forms-product-page-container-production deploy-forms-runner-container-production],
      "InProgress",
    )

    client
  end

  def self.staging_env_client
    client = stub_all_as_passing(
      Aws::CodePipeline::Client.new(stub_responses: true),
      %w[apply-forms-terraform-staging deploy-forms-product-page-container-staging deploy-forms-runner-container-staging],
    )

    stub_get_pipeline_state(client) do |pipeline_name|
      Aws::CodePipeline::Types::GetPipelineStateOutput.new(
        pipeline_name:,
        created: Time.now,
        updated: Time.now,
        pipeline_version: 2,
        stage_states: [
          Aws::CodePipeline::Types::StageState.new(
            stage_name: "stage_1",
            latest_execution: Aws::CodePipeline::Types::StageExecution.new(
              pipeline_execution_id: "execution-1",
              status: "Succeeded",
            ),
            inbound_transition_state: Aws::CodePipeline::Types::TransitionState.new(
              enabled: true,
            ),
          ),
          Aws::CodePipeline::Types::StageState.new(
            stage_name: "stage_2",
            latest_execution: Aws::CodePipeline::Types::StageExecution.new(
              pipeline_execution_id: "execution-1",
              status: "InProgress",
            ),
            inbound_transition_state: Aws::CodePipeline::Types::TransitionState.new(
              enabled: true,
            ),
          ),
          Aws::CodePipeline::Types::StageState.new(
            stage_name: "stage_3",
            latest_execution: Aws::CodePipeline::Types::StageExecution.new(
              pipeline_execution_id: "execution-2",
              status: "Succeeded",
            ),
            inbound_transition_state: Aws::CodePipeline::Types::TransitionState.new(
              enabled: true,
            ),
          ),
        ],
      )
    end

    client
  end

  def self.stub_list_pipelines(client, pipeline_names)
    client.stub_responses(
      :list_pipelines,
      Aws::CodePipeline::Types::ListPipelinesOutput.new(
        pipelines: pipeline_names.map do |name|
          Aws::CodePipeline::Types::PipelineSummary.new(
            name:,
          )
        end,
      ),
    )
  end

  def self.stub_get_pipeline_state(client, &block)
    client.stub_responses(
      :get_pipeline_state,
      lambda { |context|
        block.call(context.params[:name])
      },
    )
  end

  def self.stub_list_pipeline_executions(client, &block)
    client.stub_responses(
      :list_pipeline_executions,
      lambda { |context|
        block.call(context.params[:pipeline_name])
      },
    )
  end

  def self.stub_get_pipeline_execution_id(client, &block)
    client.stub_responses(
      :get_pipeline_execution,
      lambda { |context|
        pipeline_name = context.params[:pipeline_name]
        execution_id = context.params[:pipeline_execution_id]

        block.call(pipeline_name, execution_id)
      },
    )
  end

  def self.stub_all_as_passing(client, pipeline_names)
    stub_all_with_status(client, pipeline_names, "Succeeded")
  end

  def self.stub_all_with_status(client, pipeline_names, status)
    stub_list_pipelines(client, pipeline_names)

    stub_get_pipeline_state(client) do |pipeline_name|
      Aws::CodePipeline::Types::GetPipelineStateOutput.new(
        pipeline_name:,
        created: Time.now,
        updated: Time.now,
        pipeline_version: 2,
        stage_states: [
          Aws::CodePipeline::Types::StageState.new(
            stage_name: "stage_1",
            latest_execution: Aws::CodePipeline::Types::StageExecution.new(
              pipeline_execution_id: "execution-1",
              status:,
            ),
            inbound_transition_state: Aws::CodePipeline::Types::TransitionState.new(
              enabled: true,
            ),
          ),
          Aws::CodePipeline::Types::StageState.new(
            stage_name: "stage_2",
            latest_execution: Aws::CodePipeline::Types::StageExecution.new(
              pipeline_execution_id: "execution-1",
              status:,
            ),
            inbound_transition_state: Aws::CodePipeline::Types::TransitionState.new(
              enabled: false,
              disabled_reason: "Paused",
              last_changed_at: Time.now - (1 * 60 * 60), # 1 hour ago
            ),
          ),
        ],
      )
    end

    stub_list_pipeline_executions(client) do |_pipeline_name|
      Aws::CodePipeline::Types::ListPipelineExecutionsOutput.new(
        pipeline_execution_summaries: [
          Aws::CodePipeline::Types::PipelineExecutionSummary.new(
            start_time: Time.at(Time.now.to_i - 120),
            pipeline_execution_id: "execution-1",
            status:,
            last_update_time: Time.now,
          ),
        ],
      )
    end

    stub_get_pipeline_execution_id(client) do |pipeline_name, _execution_id|
      Aws::CodePipeline::Types::GetPipelineExecutionOutput.new(
        pipeline_execution: Aws::CodePipeline::Types::PipelineExecution.new(
          pipeline_name:,
          pipeline_version: 2,
          pipeline_execution_id: "execution-1",
          status:,
          variables: [
            Aws::CodePipeline::Types::ResolvedPipelineVariable.new(
              name: "Variable",
              resolved_value: "Some string value",
            ),
          ],
          artifact_revisions: [
            Aws::CodePipeline::Types::ArtifactRevision.new(
              name: "get-source",
              revision_id: "012abc",
              revision_summary: '{"ProviderType": "GitHub", "CommitMessage": "Some headline text\n\nFollowed by a bit more text which describes it in more detail"}',
            ),
          ],
        ),
      )
    end

    client
  end
end
