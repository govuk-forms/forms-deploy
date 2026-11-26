# frozen_string_literal: true

require "open3"
require "json"

def hcl2json(file)
  stdout, stderr, exit_status = Open3.capture3("hcl2json", file)

  warn stderr unless exit_status.success?
  JSON.parse(stdout)
end

# Per-environment rules are validation blocks in infra/deployments/forms/inputs.tf.
# This covers the one rule that spans environments.
vars_files = Dir.glob(repo_path("infra/deployments/forms/tfvars/*.tfvars")).map { |f|
  [File.basename(f), hcl2json(f)]
}.to_h

describe "terraform vars across all environments" do
  it "the Auth0 splunk stream is enabled only once" do
    enabled_statuses = vars_files.map { |_, json| json["environmental_settings"]["enable_auth0_splunk_log_stream"] }
    number_enabled = enabled_statuses.count { |enabled| enabled }

    expect(number_enabled).to be <= 1, "while we do not have an Auth0 enterprise agreement, we can have a maximum of 1 log stream enabled across all of our environments"
  end
end
