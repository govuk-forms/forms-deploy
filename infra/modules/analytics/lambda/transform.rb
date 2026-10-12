require "aws-sdk-firehose"
require "base64"
require "json"
require "set"
require "stringio"
require "time"
require "zlib"

FIREHOSE = Aws::Firehose::Client.new
STREAM_NAME = ENV.fetch("STREAM_NAME")

# PutRecordBatch accepts at most 500 records per call
BATCH_SIZE = 500
MAX_ATTEMPTS = 5
# Doubled after each failed attempt
RETRY_BASE_DELAY_SECONDS = 0.2

PREVIEW_EVENT = "form_preview_submission".freeze

# Invoked by a CloudWatch Logs subscription filter. Unwraps the gzipped
# envelope, maps each log event's message onto the submission_events table
# schema and puts each one to Firehose as its own record, because an Iceberg
# destination accepts only one JSON object per record.
#
# CloudWatch Logs delivers at least once, so the same event can arrive more
# than once. The submission reference is the idempotency key: only the first
# event with a given reference in the invocation is kept. Rows already in the
# table are not checked.
#
# A log event that cannot be mapped is logged and skipped, so that it does not
# fail the invocation and take the rest of the batch with it.
def handler(event:, context:)
  envelope = JSON.parse(Zlib::GzipReader.new(StringIO.new(Base64.decode64(event.fetch("awslogs").fetch("data")))).read)
  return if envelope["messageType"] == "CONTROL_MESSAGE"

  seen_references = Set.new

  rows = envelope["logEvents"].filter_map do |log_event|
    message = JSON.parse(log_event["message"])
    reference = message["submission_reference"]

    next if reference && !seen_references.add?(reference)

    {
      "submitted_at" => Time.iso8601(message.fetch("time")).utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
      "form_id" => message["form_id"],
      "form_name" => message["form_name"],
      "preview" => message["event"] == PREVIEW_EVENT,
      "submission_reference" => reference
    }.to_json
  rescue JSON::ParserError, KeyError, ArgumentError, TypeError => e
    warn "Skipping log event #{log_event['id']}: #{e.class}: #{e.message}"
    nil
  end

  rows.each_slice(BATCH_SIZE) do |batch|
    put_records(batch.map { |row| { data: "#{row}\n" } })
  end
end

# PutRecordBatch can partially fail, so only the records that failed are
# retried, backing off between attempts so that throttling has time to clear.
# Raising fails the invocation, which Lambda retries and then sends to the
# error bucket.
def put_records(records)
  MAX_ATTEMPTS.times do |attempt|
    sleep(RETRY_BASE_DELAY_SECONDS * (2**(attempt - 1)) * rand(0.5..1.0)) if attempt.positive?

    records = failed_records(records)
    return if records.empty?
  end

  raise "Failed to put #{records.size} records to #{STREAM_NAME}"
end

# Returns the records that were not accepted. Throttling of the whole call is
# raised by the SDK rather than reported per record, and is treated as every
# record having failed.
def failed_records(records)
  response = FIREHOSE.put_record_batch(delivery_stream_name: STREAM_NAME, records: records)
  return [] if response.failed_put_count.zero?

  records.zip(response.request_responses).filter_map { |record, result| record if result.error_code }
rescue Aws::Firehose::Errors::ServiceUnavailableException, Aws::Firehose::Errors::ThrottlingException => e
  warn "PutRecordBatch failed: #{e.class}: #{e.message}"
  records
end
