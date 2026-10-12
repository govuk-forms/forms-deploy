require "aws-sdk-firehose"
require "base64"
require "json"
require "time"
require "zlib"

FIREHOSE = Aws::Firehose::Client.new
STREAM_NAME = ENV.fetch("STREAM_NAME")

# PutRecordBatch accepts at most 500 records per call
BATCH_SIZE = 500

# Invoked by a CloudWatch Logs subscription filter with a gzipped batch of form
# submission log events. Firehose's Iceberg destination accepts only one JSON
# object per record, so each event is mapped onto the submission_events table
# schema and put as its own record.
#
# If Firehose rejects any records the invocation fails, and Lambda retries it
# and then writes it to the error bucket. A retry puts the whole batch again,
# and CloudWatch Logs delivers at least once, so the table can contain
# duplicates: count distinct submission references rather than rows.
def handler(event:, **)
  envelope = JSON.parse(Zlib.gunzip(Base64.decode64(event.fetch("awslogs").fetch("data"))))
  return if envelope["messageType"] == "CONTROL_MESSAGE"

  records = envelope["logEvents"].filter_map { |log_event| to_record(log_event) }

  records.each_slice(BATCH_SIZE) do |batch|
    response = FIREHOSE.put_record_batch(delivery_stream_name: STREAM_NAME, records: batch)
    next if response.failed_put_count.zero?

    errors = response.request_responses.filter_map(&:error_code).uniq
    raise "#{STREAM_NAME} rejected #{response.failed_put_count} of #{batch.size} records: #{errors.join(', ')}"
  end
end

# A log event that cannot be mapped is logged and skipped, so that it does not
# fail the invocation and take the rest of the batch with it.
def to_record(log_event)
  message = JSON.parse(log_event["message"])

  row = {
    submitted_at: Time.iso8601(message.fetch("time")).utc.iso8601(3),
    form_id: message["form_id"]&.to_s,
    form_name: message["form_name"],
    preview: message["event"] == "form_preview_submission",
    submission_reference: message["submission_reference"],
  }

  { data: "#{row.to_json}\n" }
rescue JSON::ParserError, KeyError, ArgumentError, TypeError => e
  warn "Skipping log event #{log_event['id']}: #{e.class}: #{e.message}"
  nil
end
