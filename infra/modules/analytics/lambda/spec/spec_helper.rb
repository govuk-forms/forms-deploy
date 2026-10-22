require "aws-sdk-firehose"

# transform.rb reads the stream name and creates its Firehose client when it
# is loaded, so both have to be set up before it is required
ENV["STREAM_NAME"] = "submission-events-test"
Aws.config[:firehose] = { stub_responses: true }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
