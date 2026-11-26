# Copilot code review instructions

This repository holds the Terraform, GitHub Actions workflows and support scripts that deploy GOV.UK Forms to AWS. Most changes apply to production through pipelines without a human reading a plan, so the review is often the only check of what an apply will do.

## How the repository works

- `infra/deployments/{deploy,forms,integration}/<root>` are Terraform roots. Each has its own S3 state. `infra/modules/` holds modules, which can't be applied on their own.
- Every environment uses the same code. Values differ in tfvars files: `infra/deployments/forms/tfvars/{dev,staging,production}.tfvars`, plus per-root `tfvars/` directories such as `forms/pipelines/tfvars`. A new variable with no default needs a value in each of them.
- Each root's `inputs.tf` and `versions.tf` are symlinks to shared files. A change to the target changes every root that links to it, and a change to a tfvars file changes every `forms` root in that environment.
- Staging and production are applied only by CodePipeline, which runs `make <env> <root> apply` with auto-approve. The `deploy/*` roots and `forms/account` are applied by hand.
- Secrets are never Terraform values. An `aws_ssm_parameter` is created with a placeholder (`dummy-value`) and `ignore_changes = [value]`, and the real value is set outside Terraform.
- `ecs-service` looks up the running container image when `image` is null, so an image changed outside Terraform is not drift.
- `forms-runner`'s queue worker (`queue_worker.tf`) builds its own container definition and secrets list. A secret or environment variable added in `main.tf` doesn't reach it.
- `modules/analytics` (used by `forms/health`) copies form submission log events into S3 tables through Firehose. `modules/grafana` queries them through Athena.

## Where a mistake costs the most

- `infra/modules/deployer-access` defines the `deployer-<env>` roles that every pipeline apply assumes. Too little permission breaks every apply in that environment. Too much is a privilege escalation. It only takes effect once `forms/account` is applied by hand in each environment.
- `modules/ecs-service` runs the production services for forms-admin, forms-product-page and forms-runner, with `prevent_destroy` because replacing a service causes downtime. Flag a change that would force a replacement, such as a renamed service or a changed immutable argument.
- `modules/analytics` and `modules/grafana` hold form submission data. Grafana runs on a public load balancer with no WAF, and GitHub sign-in is its only access control. Flag a change that widens who can query the tables, adds submission fields to them, or alters Grafana's sign-in or role mapping.
- `modules/rds` keeps `restore_to_point_in_time` in `ignore_changes` on purpose. Flag its removal.
- `forms/account` and `deploy/*` have no pipeline in front of them.
- The Lambdas in `forms/pipelines` and `support/paused-pipeline-detector` run in production.

## What CI doesn't check

Pull requests get `terraform validate` with `-backend=false`, never a `plan`. So these are down to you:

- Resources that would be replaced or destroyed, including a changed `for_each` key or a rename with no `moved` block.
- A new variable that is missing from one environment's tfvars.
- IAM breadth. Only Checkov's built-in rules look at it.
- A new `#checkov:skip`. Each one should have a reason after the check ID.
- Behaviour of new Ruby, shell or Lambda code beyond what its specs cover.

## What CI already checks

Don't comment on these. Only `Shell`, `Run pre-commit` and `Run terraform tests` are required to merge, so a failure in the rest, including the Ruby specs, doesn't block a merge on its own.

- Formatting, `tflint` (including naming), and Checkov, including the custom checks in `infra/checkov/` for alarm actions, EventBridge dead letter queues, SSM `ignore_changes`, autoscaling minimums and unique listener rule priorities.
- Unused variables. The `tflint` rule is off on purpose because roots share `inputs.tf`.
- `running-order.yml` listing every root, and the capacity, CPU and domain rules in `infra/spec/deployments/forms/tfvars/vars_spec.rb`.
- Tool versions in step across files, actions pinned to a commit SHA, unique job names, `shellcheck` and `rubocop` (the GOV.UK rules).

## How to comment

- Put the problem with the widest blast radius first. One comment per problem, saying what breaks and when.
- Skip a risk that the pull request description lists as deliberate, or that a README in the changed directory already accepts, unless the change makes it worse.
- Don't repeat a finding you already raised on this pull request.
