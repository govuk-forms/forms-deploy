# analytics

Streams `form_submission` and `form_preview_submission` log events from the
forms-runner CloudWatch log group to an Apache Iceberg table in S3 Tables, via
a subscription filter, a Lambda and a Kinesis Data Firehose stream.

```
/aws/ecs/forms-runner-<env>
  → subscription filter { $.event = "form_submission" || $.event = "form_preview_submission" }
  → Lambda (unwraps the CloudWatch Logs envelope, one Firehose record per event)
  → Firehose
  → S3 Table s3tablescatalog/govuk-forms-<env>-analytics, forms.submission_events
```

CloudWatch Logs batches several log events into one gzipped payload, but an
Iceberg destination accepts only one JSON object per Firehose record. So the
subscription filter invokes a Lambda (lambda/transform.rb) rather than the
stream; the Lambda maps each log event onto the table schema and puts each
one to the stream as its own record.

The table schema is `submitted_at` (timestamp, renamed from the log event's
`time` field and normalised to UTC), `form_id` and `form_name` (strings),
`preview` (boolean, true for `form_preview_submission` events) and
`submission_reference` (string). All other log fields are dropped by the
Lambda.

The table is unpartitioned so that it can be fully managed by Terraform (the
provider cannot yet set an Iceberg partition spec). At our volumes Iceberg's
per-file column statistics keep time-range queries cheap regardless.

## Duplicates

CloudWatch Logs delivers at least once. The Lambda uses the submission
reference as an idempotency key and keeps only the first event with each
reference in an invocation. It does not check rows already in the table, so
the same submission can still appear twice if it is delivered in separate
invocations, or if an invocation is retried after some of its records were
put to the stream.

## Failures

Both kinds of failure land in the `govuk-forms-<env>-analytics-errors`
bucket:

- invocations of the Lambda that still fail after Lambda's retries, for
  example because the stream kept rejecting records
- records Firehose cannot deliver to the table

A log event the Lambda cannot map onto the table schema (invalid JSON, or a
missing or malformed `time`) is skipped rather than failing the invocation.
It is not written to the error bucket; the Lambda logs its CloudWatch Logs
event ID to `/aws/lambda/submission-events-transform-<env>`.

## Querying

In Athena, select catalog `s3tablescatalog/govuk-forms-<env>-analytics`
and database `forms`:

```sql
SELECT * FROM submission_events ORDER BY submitted_at DESC LIMIT 10;
```
