# forms-deploy

`forms-deploy` composes and deploys the different components of GOV.UK Forms to create a full environment. The major components of the repository are

- [Infrastructure](https://github.com/govuk-forms/forms-deploy/blob/main/infra/README.md)
- [Local development](https://github.com/govuk-forms/forms-deploy/blob/main/local/README.md)
- [Supporting scripts](https://github.com/govuk-forms/forms-deploy/tree/main/support)

## Table of contents

1. [How do I use this repository?](#how-do-i-use-this-repository)
2. [Common tasks](#common-tasks)
3. [Directory of URLs](#directory-of-urls)

## How do I use this repository?

Operations in this repository are largely driven by `make`, and defined in [the `Makefile`](./Makefile).

Using `make` it is possible to deploy any part of the infrastructure to any account. We have designed our Make targets to act like a small CLI tool [^1], and the general structure is

```
make $ACCOUNT $ROOT $ACTION
```

where

- `$ACCOUNT` is the name of the account you have assumed a role in (one of `deploy`, `development`, `staging`, and `production`)
- `$ROOT` is a Terraform root module folder under `infra/deployments`. For example `forms/rds` or `deploy/ecr`.
- `$ACTION` is the Terraform action you want to take. One of `plan`, `apply,` and `validate`.

> [!TIP]
> Our `make` commands have tab completion! Source the tab completion script for your shell under `support/` (e.g. `support/makefile_completion.bash`) as part of your shell profile.

## Tooling

[mise-en-place](https://mise.jdx.dev/) can be used in this repository for tool management, in the same way as `rbenv` / `nvm` / `pyenv` etc.

Tool versions are all configured in [.mise.toml](.mise.toml). After installing & configuring `mise`, you can install all tools at their specified versions with `mise install`.

`mise` is also used in [GitHub actions workflows](.github/workflows/) for fetching tool versions. This allows us to configure versions in one single place, rather than having to remember to update
version numbers in multiple files. It also makes it very easy to extract version numbers without manually parsing files.

If you would prefer not to use `mise` locally, and are experiencing errors or strange behaviour when running scripts in this repository, ensure that you have installed the tools with the specific versions specified in `.mise.toml`.

## Common tasks

#### Testing infrastructure changes with the deployer role (dev only)

For testing Terraform operations in the same context as CI pipelines, admin engineers can assume the deployer role directly from their local machines. This functionality is only available for the **dev environment**.

Use the deployer role for dev environment Terraform operations:

```bash
# Test a plan operation
gds aws forms-dev-admin -- make dev deployer_role forms/forms-admin plan

# Apply changes using the deployer role
gds aws forms-dev-admin -- make dev deployer_role forms/rds apply
```

> [!IMPORTANT]
>
> - The deployer role functionality is **only available for the dev environment**
> - The deployer role credentials are only active within the make command - they don't persist in your shell session
> - You must include `deployer_role` in the same command as your Terraform action

> [!NOTE]
> This is primarily for testing permissions and validating changes in dev. All other environments (staging, production, user-research) should only be deployed through the CI pipeline.

#### Updating Terraform

We have a lot of Terraform code, across a lot of distinct root modules. To keep versioning consistent we have [a shared versions file](infra/shared/versions.tf.json) which is symlinked into each root.

To simplify performing the upgrade, you can run

```
./infra/scripts/upgrade_tf_version.sh
```

This will find the latest version of Terraform and all of the Terraform providers we use, update the versions file with them, and then update the lock files in each root.

## Directory of URLs

### Admin

- Staging: https://admin.staging.forms.service.gov.uk/
- Production: https://admin.forms.service.gov.uk/

### Runner

- Staging: https://submit.staging.forms.service.gov.uk/
- Production: https://submit.forms.service.gov.uk/

### Architecture decision records

https://github.com/govuk-forms/forms/tree/main/ADR

[^1]: This should not be confused with `forms-cli` at `support/forms-cli`. `forms-cli` is intended for working with a deployment of GOV.UK Forms, not deploying it.

### Path to production for apps

https://github.com/govuk-forms/forms-team/wiki/Deploying-to-production%3a-applications

### Path to production for Terraform

https://github.com/govuk-forms/forms-team/wiki/Deploying-to-production%3a-Terraform

### Pipeline Visualiser

https://pipelines.tools.forms.service.gov.uk/
