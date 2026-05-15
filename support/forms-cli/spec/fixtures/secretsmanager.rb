# frozen_string_literal: true

require "time"

# Fixtures for secrets manager api calls
module SecretsManagerFixtures
  @secrets_manager_stub = Aws::SecretsManager::Client.new({ stub_responses: true })

  def self.list_secrets
    @secrets_manager_stub.stub_data(:list_secrets,
                                    {
                                      secret_list: [
                                        {
                                          arn: "arn-for-forms-admin-database-credentials",
                                          description: "forms-admin-database credentials",
                                          last_changed_date: Time.parse("2023-01-01"),
                                          name: "forms-admin-database",
                                          secret_versions_to_stages: {
                                            "EXAMPLE1-90ab-cdef-fedc-ba987EXAMPLE" => %w[
                                              AWSCURRENT
                                            ],
                                          },
                                        },
                                      ],
                                    })
  end

  def self.empty_list_secrets
    @secrets_manager_stub.stub_data(:list_secrets, { secret_list: [] })
  end

  def self.describe_secret
    @secrets_manager_stub.stub_data(:describe_secret,
                                    {
                                      arn: "arn:aws:secretsmanager:eu-west-2:123456789012:secret:rds-db-credentials/cluster-resource-id/forms-admin-AbCdEf",
                                      name: "rds-db-credentials/cluster-resource-id/forms-admin",
                                      description: "Data API credentials for forms-admin in dev environment",
                                    })
  end
end
