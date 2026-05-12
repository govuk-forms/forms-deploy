# frozen_string_literal: true

require "utilities/helpers"

describe Helpers do
  let(:dummy_class) { Class.new { include Helpers } }

  describe ".aws_authenticated?" do
    context "when not authenticated" do
      it "returns false and prints warning to stdout" do
        result = nil
        expect { result = dummy_class.new.aws_authenticated? }.to output(/You must be authenticated/).to_stdout
        expect(result).to be false
      end
    end

    context "when authenticated" do
      it "returns true" do
        stub_const("ENV",
                   {
                     "AWS_ACCESS_KEY_ID" => "test_key_id",
                     "AWS_REGION" => "test_region",
                     "AWS_SESSION_TOKEN" => "test_token",
                     "AWS_SECRET_ACCESS_KEY" => "test_secret_key",
                   })
        expect(dummy_class.new.aws_authenticated?).to be true
      end
    end
  end

  describe "forms_app_host" do
    [
      ["admin", "dev", "admin.dev.forms.service.gov.uk"],
      ["product-page", "production", "forms.service.gov.uk"],
      ["runner", "staging", "submit.staging.forms.service.gov.uk"],
    ].each do |app, environment, expected|
      it "returns the #{app} host name in #{environment}" do
        expect(dummy_class.new.forms_app_host(app, environment:)).to eq expected
      end
    end
  end
end
