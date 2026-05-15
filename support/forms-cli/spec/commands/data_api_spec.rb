# frozen_string_literal: true

require "commands/data_api"
require "utilities/data_api_connection"

require_relative "../fixtures/rdsdataservice"

describe DataApi do
  context "when not authenticated" do
    it "prompts the user to authenticate" do
      expect { described_class.new.run }.to output(/You must be authenticated/).to_stdout
    end
  end

  context "when authenticated" do
    let(:data_api_connection_mock) do
      data_api_connection_mock = instance_double(DataApiConnection)
      allow(data_api_connection_mock)
        .to receive(:execute_statement)
        .and_return(RDSDataServiceFixtures.execute_statement)

      data_api_connection_mock
    end

    before do
      stub_const("ARGV", ["-d", "forms-admin", "-c", "cluster-name", "-s", "select * from testing;"])

      allow_any_instance_of(Helpers) # rubocop:todo RSpec/AnyInstance
        .to receive_messages(aws_authenticated?: true, fetch_environment: "dev")

      allow(DataApiConnection)
        .to receive(:new)
        .and_return(data_api_connection_mock)
    end

    it "-d, --database and -c, --cluster are correctly passed to DataApiConnection" do
      described_class.new.run

      expect(DataApiConnection)
        .to have_received(:new)
        .with("dev", "forms-admin", "cluster-name", nil)
        .at_least(:once)
    end

    it "-s, --statement is correctly passed to DataApiConnection" do
      described_class.new.run

      expect(data_api_connection_mock)
        .to have_received(:execute_statement)
        .with("select * from testing;")
        .at_least(:once)
    end
  end
end
