# analytics

Streams `form_submission` log events from the forms-runner CloudWatch log
group to an Apache Iceberg table in S3 Tables, via a subscription filter and a
Kinesis Data Firehose stream.

```
/aws/ecs/forms-runner-<env>
  → subscription filter { $.event = "form_submission" }
  → Firehose (transform Lambda unwraps the CloudWatch Logs envelope)
  → S3 Table s3tablescatalog/govuk-forms-<env>-analytics, forms.submission_events
```

A transform Lambda (lambda/transform.rb) gunzips each CloudWatch Logs record
and maps its log events onto the table schema as newline-delimited JSON;
Firehose's built-in decompression processor only supports the S3, Splunk and
Snowflake destinations, not Iceberg. Firehose invokes the Lambda with batches
of records (up to 3 MB or 60 seconds of buffered data per invocation), not
once per event.

The table schema is `submitted_at` (timestamp, renamed from the log event's
`time` field and normalised to UTC), `form_id` and `form_name` (strings) and
`preview` (boolean). All other log fields are dropped by the Lambda. Records
Firehose cannot deliver land in the
`govuk-forms-<env>-analytics-errors` bucket.

The table is unpartitioned so that it can be fully managed by Terraform (the
provider cannot yet set an Iceberg partition spec). At our volumes Iceberg's
per-file column statistics keep time-range queries cheap regardless.

## Querying

In Athena, select catalog `s3tablescatalog/govuk-forms-<env>-analytics`
and database `forms`:

```sql
SELECT * FROM submission_events ORDER BY submitted_at DESC LIMIT 10;
```

## Notes

- CloudWatch Logs sends a control message when the subscription filter is
  created; the transform Lambda drops it.
- Preview submissions are included, with `preview = true`.
