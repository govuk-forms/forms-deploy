# frozen_string_literal: true

require "utilities/data_api_connection"

require_relative "../fixtures/secretsmanager"
require_relative "../fixtures/rds"
require_relative "../fixtures/rdsdataservice"

describe DataApiConnection do
  let(:secrets_manager_mock) do
    secrets_manager_mock = instance_double(Aws::SecretsManager::Client)
    allow(secrets_manager_mock)
      .to receive(:describe_secret)
      .with(hash_including(secret_id: "rds-db-credentials/cluster-resource-id/forms-admin"))
      .and_return(SecretsManagerFixtures.describe_secret)

    secrets_manager_mock
  end

  let(:rds_mock) do
    rds_mock = instance_double(Aws::RDS::Client)
    allow(rds_mock)
      .to receive(:describe_db_clusters)
      .and_return(RDSFixtures.describe_db_clusters)

    rds_mock
  end

  let(:data_api_mock) do
    data_api_mock = instance_double(Aws::RDSDataService::Client)
    allow(data_api_mock)
      .to receive(:execute_statement)
      .and_return(RDSDataServiceFixtures.execute_statement)

    data_api_mock
  end

  before do
    allow(Aws::SecretsManager::Client)
      .to receive(:new)
      .and_return(secrets_manager_mock)

    allow(Aws::RDS::Client)
      .to receive(:new)
      .and_return(rds_mock)

    allow(Aws::RDSDataService::Client)
      .to receive(:new)
      .and_return(data_api_mock)
  end

  it "set correct rds cluster arn and secret arn" do
    described_class.new("dev", "forms-admin", "cluster-name").execute_statement("select * from testing;")

    expect(data_api_mock)
      .to have_received(:execute_statement)
      .with(hash_including(
              resource_arn: "cluster-arn",
              secret_arn: "arn:aws:secretsmanager:eu-west-2:123456789012:secret:rds-db-credentials/cluster-resource-id/forms-admin-AbCdEf",
            ))
      .at_least(:once)
  end

  context "when cluster is nil or empty" do
    it "uses the default cluster name" do
      described_class.new("dev", "forms-admin", nil).execute_statement("select * from testing;")

      expect(rds_mock)
        .to have_received(:describe_db_clusters)
        .with(hash_including(db_cluster_identifier: "aurora-v2-cluster-dev"))
        .at_least(:once)
    end
  end

  it "database_name is correctly passed to secrets manager" do
    described_class.new("dev", "forms-admin", "cluster-name").execute_statement("select * from testing;")

    expect(secrets_manager_mock)
      .to have_received(:describe_secret)
      .with(hash_including(secret_id: "rds-db-credentials/cluster-resource-id/forms-admin"))
      .at_least(:once)
  end

  it "database_name is correctly passed to data api" do
    described_class.new("dev", "forms-admin", "cluster-name").execute_statement("select * from testing;")

    expect(data_api_mock)
      .to have_received(:execute_statement)
      .with(hash_including(database: "forms-admin"))
      .at_least(:once)
  end

  it "statement is correctly passed" do
    described_class.new("dev", "forms-admin", "cluster-name").execute_statement("select * from testing;")

    expect(data_api_mock)
      .to have_received(:execute_statement)
      .with(hash_including(sql: "select * from testing;"))
      .at_least(:once)
  end

  it "parses records returned into an array of hashes" do
    response = described_class.new("dev", "forms-admin", "cluster-name").execute_statement("select * from testing;")

    expect(response.formatted_records).to eq('[{"id": 1, "name": "some-form"}]')
    expect(response.records).to eq([{ id: 1, name: "some-form" }])
  end

  context "when secret does not exist in Secrets Manager" do
    let(:secrets_manager_mock_no_secret) do
      secrets_manager_mock_no_secret = instance_double(Aws::SecretsManager::Client)
      allow(secrets_manager_mock_no_secret)
        .to receive(:describe_secret)
        .with(hash_including(secret_id: "rds-db-credentials/cluster-resource-id/forms-admin"))
        .and_raise(Aws::SecretsManager::Errors::ResourceNotFoundException.new("context", "Secret not found"))

      secrets_manager_mock_no_secret
    end

    before do
      allow(Aws::SecretsManager::Client)
        .to receive(:new)
        .and_return(secrets_manager_mock_no_secret)
    end

    it "raises an error about missing secret" do
      expect {
        described_class.new("dev", "forms-admin", "cluster-name").execute_statement("select * from testing;")
      }.to raise_error(/Data API credential secret 'rds-db-credentials\/cluster-resource-id\/forms-admin' was not found/)
    end
  end
end
