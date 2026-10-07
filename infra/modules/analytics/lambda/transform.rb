require "base64"
require "json"
require "stringio"
require "time"
require "zlib"

# Firehose transform: unwraps the gzipped CloudWatch Logs envelope and maps
# each log event's message onto the submission_events table schema, one JSON
# object per line. Exactly one output record per input record.
def handler(event:, context:)
  records = event["records"].map do |record|
    begin
      envelope = JSON.parse(Zlib::GzipReader.new(StringIO.new(Base64.decode64(record["data"]))).read)

      if envelope["messageType"] == "CONTROL_MESSAGE"
        { "recordId" => record["recordId"], "result" => "Dropped" }
      else
        lines = envelope["logEvents"].map do |log_event|
          message = JSON.parse(log_event["message"])
          {
            "submitted_at" => Time.iso8601(message.fetch("time")).utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
            "form_id" => message["form_id"],
            "form_name" => message["form_name"],
            "preview" => message["preview"] == "true"
          }.to_json
        end
        {
          "recordId" => record["recordId"],
          "result" => "Ok",
          "data" => Base64.strict_encode64(lines.join("\n"))
        }
      end
    rescue JSON::ParserError, KeyError, ArgumentError, Zlib::GzipFile::Error
      { "recordId" => record["recordId"], "result" => "ProcessingFailed", "data" => record["data"] }
    end
  end

  { "records" => records }
end
