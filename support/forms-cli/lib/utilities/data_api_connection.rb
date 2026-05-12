# frozen_string_literal: true

require "json"
require "ostruct"

require "aws-sdk-secretsmanager"
require "aws-sdk-rds"
require "aws-sdk-rdsdataservice"

# Executes statements on AWS RDS using the Data API.
class DataApiConnection
  def initialize(env, database_name, cluster_name)
    @env = env
    @database_name = database_name
    @cluster_name = cluster_name || default_cluster_name

    @data_service = Aws::RDSDataService::Client.new
    @rds = Aws::RDS::Client.new
    @secrets_manager = Aws::SecretsManager::Client.new
  end

  def execute_statement(statement, params = {})
    params = {
      resource_arn: query_database_cluster_arn,
      secret_arn: query_credential_arn,
      sql: statement,
      database: @database_name,
      include_result_metadata: true,
      format_records_as: "JSON", # Its simpler to get the results as JSON and parse it back...
    }.merge(params)

    response = @data_service.execute_statement(params)

    OpenStruct.new(response.to_hash.merge({
      records: JSON.parse(response.formatted_records || "[]", symbolize_names: true),
    }))
  end

private

  def default_cluster_name
    "aurora-v2-cluster-#{@env}"
  end

  def query_credential_arn
    secret_name = "rds-db-credentials/#{query_database_resource_id}/#{@database_name}"
    # secret_name = "data-api/#{@env}/#{@database_name}/rds-credentials"

    begin
      secret = @secrets_manager.describe_secret({ secret_id: secret_name })
      secret.arn
    rescue Aws::SecretsManager::Errors::ResourceNotFoundException
      raise "Data API credential secret '#{secret_name}' was not found. Ensure the secret is created in Terraform."
    end
  end

  def query_database_cluster_arn
    params = { db_cluster_identifier: @cluster_name }
    arn = @rds.describe_db_clusters(params)&.db_clusters&.[](0)&.db_cluster_arn

    raise "Database cluster was not be found" if arn.nil?

    arn
  end

  def query_database_resource_id
    params = { db_cluster_identifier: @cluster_name }
    resource_id = @rds.describe_db_clusters(params)&.db_clusters&.[](0)&.db_cluster_resource_id

    raise "Database cluster was not found" if resource_id.nil?

    resource_id
  end
end
