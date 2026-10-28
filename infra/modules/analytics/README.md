# Analytics

An S3 table bucket, `govuk-forms-<environment>-analytics`, with Iceberg tables
in the `forms` namespace. Each table is written by its own Firehose stream and
is queried with Athena through the `s3tablescatalog` federated Glue catalog,
which is created in `forms/account`. This module is used by the `forms/health`
root.

Records Firehose can't deliver to a table are written to the
`govuk-forms-<environment>-analytics-errors` bucket.

## Tables

### `submission_events`

One row per form submission, including preview submissions. A subscription
filter on the forms-runner log group sends `form_submission` and
`form_preview_submission` log events to the `submission-events-transform`
Lambda, which maps each one onto the table schema and puts it to the
`submission-events-<environment>` stream.

Delivery is at least once, so count distinct `submission_reference`s rather
than rows.

### `form_snapshots`

One row per form per daily run: the form's `state`, organisation and a JSON
object of feature flags in `properties`. A forms-admin scheduled task
(`rake analytics:snapshot_forms`, at 22:00 UTC) puts the rows straight to the
`form-snapshots-<environment>` stream. Its delivery errors go to the
`form-snapshots/` prefix in the error bucket.

`snapshot_at` is the same on every row in a run. Queries should pick the
latest run in each period and count distinct `form_id`s, so reruns, duplicates
and missed days don't change the counts.

Rows before the first scheduled run are backfilled with
`rake analytics:backfill_form_snapshots` and are approximate: `state` is only
`draft`, `live` or `archived`, and `properties` is `NULL` where it isn't
known. Record the date of the first scheduled run here once it has happened.

## Changing a table

Tables have `prevent_destroy` set. Destroying or replacing a table deletes its
data, and any change to its metadata in Terraform forces a replacement. Make
schema changes, such as adding a column, outside Terraform, or migrate the
data first.

## Applying

Apply `forms/account` first if the deployer permissions in
`infra/modules/deployer-access` have changed. Firehose checks that the
destination table exists when a stream is created, so the table and stream are
created in the same apply of `forms/health`.
