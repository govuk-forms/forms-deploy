@AGENTS.md

## What this repo is

Terraform for GOV.UK Forms, driven by `make`. Roots live in `infra/deployments/{forms,deploy,integration}/<root>` and each has its own state. Reusable modules are in `infra/modules`. `forms` is parameterised per environment (dev, staging, production) by `tfvars/*.tfvars`; `deploy` is a single environment. `support/forms-cli` is for working with a running deployment, not for deploying it.

## Commands

```bash
make <env> <deployment>/<root> <action>   # e.g. make dev forms/rds plan (init, plan, apply, validate)
make dev deployer_role forms/rds plan     # dev only: runs with the CI deployer role
make fmt                                  # terraform fmt (CHANGED_FILES="a.tf b.tf" to narrow)
make lint                                 # checkov, tflint, spec, lint_ruby
make spec                                 # rspec in infra, support/pipeline-visualiser and two lambda dirs
make lint_ruby                            # rubocop
mise install                              # tool versions come from .mise.toml
pre-commit run --all-files
```

`plan`, `apply` and `validate` need an assumed AWS role (`gds aws <profile> -- make ...`). Staging and production are applied only by the CodePipeline pipelines, never by hand.

## Gotchas

- `infra/deployments/running-order.yml` is parsed to build the pipelines. A new root has to be added there or it won't deploy. It is checked against `infra/spec/deployments/running_order_schema.json`.
- Each root's `inputs.tf` and `versions.tf` are symlinks to shared files. Edit the target, not the link.
- Roots can have `pre-apply.sh` and `post-apply.sh` hooks (see `forms/rds`).
- Tool versions are pinned in `.mise.toml`, and some are repeated in `.pre-commit-config.yaml` and workflow files with "keep in step" comments. Bump them together. The `guardrail_versions_in_sync` workflow runs `support/check-versions-in-sync.sh` and fails CI when they drift. Terraform and Ruby are the exception: their versions come from `.terraform-version` and `.ruby-version`, which mise reads.
- `infra/deployments/integration` (`account`, `review`) holds the review-app setup. It isn't a normal environment, so check the `make` targets before assuming `make integration …` behaves like `dev`.
- After changing `infra/modules/deployer-access`, apply `forms/account` in each affected environment (`make <env> forms/account apply`) and check the `apply-forms-terraform-<env>` pipelines succeed.
