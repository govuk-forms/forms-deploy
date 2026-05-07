# frozen_string_literal: true

require "colorize"
require "aws-sdk-sts"

# Helper methods for common operations
module Helpers
  ACCOUNT_IDS = {
    "498160065950" => "dev",
    "972536609845" => "staging",
    "443944947292" => "production",
  }.freeze

  DOMAINS = {
    "dev" => "dev.forms.service.gov.uk",
    "staging" => "staging.forms.service.gov.uk",
    "production" => "forms.service.gov.uk",
  }.freeze

  def aws_authenticated?
    return true if expected_aws_environment_variable

    puts "You must be authenticated to run this command. Use --help"\
      " for further instructions".red
    false
  end

  def fetch_environment
    if ENV["FORMS_ENV"].nil? || ENV["FORMS_ENV"].empty?
      sts = Aws::STS::Client.new
      account = sts.get_caller_identity({}).account
      ACCOUNT_IDS[account]
    else
      ENV["FORMS_ENV"]
    end
  end

  def forms_app_host(app, environment: nil)
    environment ||= fetch_environment
    domain = DOMAINS.fetch environment
    subdomain = {
      "admin" => "admin.",
      "product-page" => "",
      "runner" => "submit.",
    }.fetch app

    "#{subdomain}#{domain}"
  end

private

  def expected_aws_environment_variable
    !ENV["AWS_ACCESS_KEY_ID"].nil? &&
      !ENV["AWS_REGION"].nil? &&
      !ENV["AWS_SECRET_ACCESS_KEY"].nil? &&
      !ENV["AWS_SESSION_TOKEN"].nil?
  end
end
