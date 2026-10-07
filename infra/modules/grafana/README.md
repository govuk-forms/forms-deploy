# Grafana

Runs Grafana OSS as a single Fargate task behind its own public ALB at
`grafana.<root_domain>`, backed by its own Aurora Serverless v2 PostgreSQL
cluster. The load balancer is public and is not behind CloudFront or a WAF;
GitHub sign in is the only access control. Data sources for CloudWatch,
X-Ray (Application Signals) and Athena are provisioned at start up and
authenticate with the task role. Grafana alerting is disabled.

## Signing in

Users sign in with GitHub and are sent straight to GitHub when they visit
Grafana. Access is limited to members of the organisations in
`github_allowed_organizations`, and a role is assigned from team membership:
`github_admin_team` members are Grafana server admins, `github_editor_teams`
members are editors, and anybody else is refused.

The built-in `admin` user remains for use when GitHub sign in is unavailable.
Its password is in the SSM parameter `/grafana/admin-password` and the login
form is reachable at `/login?disableAutoLogin=true`.

## Setting up an environment

1. Apply `forms/account` (deployer permissions), `forms/environment` (public
   subnet outputs and the ALB logs bucket policy), then `forms/health` (this
   module) and `forms/dns` (the record).
2. Create a GitHub OAuth App in the organisation with the homepage URL
   `https://grafana.<root_domain>` and the authorization callback URL
   `https://grafana.<root_domain>/login/github`. If the organisation restricts
   third-party OAuth apps, approve it for the organisation.
3. Put the app's client ID and secret in the SSM parameters
   `/grafana/github/client-id` and `/grafana/github/client-secret`.
4. Force a new deployment of the `grafana` ECS service so the task picks the
   values up.

## Querying with Athena

The Athena data source runs queries in the `grafana` workgroup, which writes
results to the `govuk-forms-<environment>-grafana-athena-results` bucket and
cancels any query that scans more than
`athena_bytes_scanned_cutoff_per_query` bytes. It can see every database and
table in the Glue data catalog, but Athena reads the underlying objects as the
task role, so the buckets holding the data must be listed in
`athena_data_bucket_arns` before their tables can be queried.

The data source selects the S3 Tables catalog holding submission events,
`s3tablescatalog/govuk-forms-<environment>-analytics`, and its `forms`
database by default. Athena is vended credentials for that catalog through
Lake Formation. The catalog grants `IAM_ALLOWED_PRINCIPALS`, so no Lake
Formation grants are expected. If queries fail with "Insufficient Lake
Formation permission(s)", grant the task role `SELECT` and `DESCRIBE` on the
catalog `<account id>:s3tablescatalog/<table bucket>` with
`aws_lakeformation_permissions`.

## Notes

- The database is allowed to pause after `seconds_until_auto_pause` seconds
  without connections, but Grafana keeps a connection pool open, so in
  practice it only pauses while the service is stopped.
- The plugins are downloaded from grafana.com when the task starts, so the
  task needs internet egress and a start takes a minute or two.
