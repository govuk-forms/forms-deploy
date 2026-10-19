require "base64"
require "json"
require "stringio"
require "zlib"
require "spec_helper"

require_relative "../transform"

describe "#handler" do
  let(:submission) do
    {
      "event" => "form_submission",
      "form_id" => "1",
      "form_name" => "Test form",
      "level" => "INFO",
      "message" => "Form event",
      "preview" => false,
      "request_id" => "00000000-0000-0000-0000-000000000000",
      "submission_reference" => "TESTREF1",
      "time" => "2026-01-01T12:00:00.123+00:00",
    }
  end

  let(:messages) { [submission] }

  let(:envelope) do
    {
      "messageType" => "DATA_MESSAGE",
      "logGroup" => "/aws/ecs/forms-runner-test",
      "logEvents" => messages.each_with_index.map do |message, index|
        { "id" => "event-#{index}", "message" => message.is_a?(String) ? message : message.to_json }
      end,
    }
  end

  let(:event) do
    gzipped = StringIO.new
    Zlib::GzipWriter.wrap(gzipped) { |gzip| gzip.write(envelope.to_json) }
    { "awslogs" => { "data" => Base64.strict_encode64(gzipped.string) } }
  end

  let(:all_accepted) do
    lambda do |context|
      {
        failed_put_count: 0,
        request_responses: context.params[:records].map { { record_id: "record" } },
      }
    end
  end

  def put_record_batch_requests
    FIREHOSE.api_requests.select { |request| request[:operation_name] == :put_record_batch }
  end

  def put_rows
    put_record_batch_requests.flat_map do |request|
      request[:params][:records].map { |record| JSON.parse(record[:data]) }
    end
  end

  def run_handler
    handler(event:, context: nil)
  end

  before do
    FIREHOSE.api_requests.clear
    FIREHOSE.stub_responses(:put_record_batch, all_accepted)
  end

  it "puts a submission onto the stream as a row in the table's schema" do
    row = {
      submitted_at: "2026-01-01T12:00:00.123Z",
      form_id: "1",
      form_name: "Test form",
      preview: false,
      submission_reference: "TESTREF1",
    }

    run_handler

    expect(put_record_batch_requests.first[:params]).to eq(
      delivery_stream_name: "submission-events-test",
      records: [{ data: "#{row.to_json}\n" }],
    )
  end

  it "normalises the submission time to UTC" do
    submission["time"] = "2026-01-01T13:00:00.123+01:00"

    run_handler

    expect(put_rows.first["submitted_at"]).to eq("2026-01-01T12:00:00.123Z")
  end

  it "marks preview submissions as previews" do
    submission["event"] = "form_preview_submission"

    run_handler

    expect(put_rows.first["preview"]).to be(true)
  end

  it "puts the form ID as a string" do
    submission["form_id"] = 1

    run_handler

    expect(put_rows.first["form_id"]).to eq("1")
  end

  context "when CloudWatch Logs sends a control message" do
    let(:envelope) { { "messageType" => "CONTROL_MESSAGE", "logEvents" => [] } }

    it "puts nothing onto the stream" do
      run_handler

      expect(put_record_batch_requests).to be_empty
    end
  end

  context "when some events cannot be mapped onto the table schema" do
    let(:messages) do
      [
        "not json",
        submission.except("time").merge("submission_reference" => "TESTREF2"),
        submission.merge("submission_reference" => "TESTREF3", "time" => "yesterday"),
        submission,
      ]
    end

    it "skips them, logs their IDs and puts the rest" do
      expect { run_handler }.to output(/event-0.*event-1.*event-2/m).to_stderr

      expect(put_rows.map { |row| row["submission_reference"] }).to eq(%w[TESTREF1])
    end
  end

  context "when there are more events than fit in one batch" do
    let(:messages) do
      Array.new(501) { |index| submission.merge("submission_reference" => "TESTREF#{index}") }
    end

    it "puts them in batches of 500" do
      run_handler

      expect(put_record_batch_requests.map { |request| request[:params][:records].size }).to eq([500, 1])
    end
  end

  context "when the stream rejects some records" do
    let(:messages) { [submission, submission.merge("submission_reference" => "TESTREF2")] }

    before do
      FIREHOSE.stub_responses(
        :put_record_batch,
        {
          failed_put_count: 1,
          request_responses: [
            { record_id: "record" },
            { error_code: "ServiceUnavailableException", error_message: "Slow down" },
          ],
        },
      )
    end

    it "fails the invocation so that Lambda retries it" do
      expect { run_handler }.to raise_error(
        "submission-events-test rejected 1 of 2 records: ServiceUnavailableException",
      )
    end
  end
end
