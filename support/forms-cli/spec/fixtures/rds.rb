# frozen_string_literal: true

require "time"

# Fixtures for secrets manager api calls
module RDSFixtures
  @rds_stub = Aws::RDS::Client.new({ stub_responses: true })

  def self.describe_db_clusters
    @rds_stub.stub_data(:describe_db_clusters,
                        { db_clusters: [{ db_cluster_arn: "cluster-arn", db_cluster_resource_id: "cluster-resource-id" }] })
  end
end
