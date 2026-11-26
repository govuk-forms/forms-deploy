## GOV.UK Forms Infrastructure

### Introduction

All infrastructure for GOV.UK Forms is managed within this directory using Terraform. The `infra/deployments` directory contains all of the Terraform deployments from which the `terraform` commands should be run. The `deployments` directory contains 3 distinct deployments:

* `account`, which lays the groundwork in an AWS account, and should only ever be run by a human. It does things like configuring engineer access, and ensuring DNS hosted zones exist.
* `deploy`, which configures all of the pipelines and continer repositories in the central `deploy` AWS account
* `forms`, which configures a full deployment of the GOV.UK Forms service; this deployment is parameterised to support different environments from the same codebase.

The `modules` directory contains reusable Terraform modules which are referenced by the various deployments.

### Terminology

**root:** a Terraform root module, with its own state file. When applied, it manages infrastructure for a subset of the overall deployment.

**deployment:** a set of one or more roots that, in combination, describe a full set of infrastructure for some purpose.

**module:** a (reusable) Terraform module. It cannot be independently deployed.

### How to manage the deployments

The majority of the roots are applied automatically as part of deployment pipelines. However, those for the `deploy` account (under [the `deployments/deploy` directory](deployments/deploy/)) are currently applied manually.

This is also true for the `forms/account` root, which is intended to only ever be run by a human. The `forms/account` root lays the groundwork within an AWS account, and manages things like engineer access.

### Applying Terraform manually

To apply a Terraform root (such as `forms-runner` in the `forms` deployment) in an environment (such as `dev`):

1. Use the [GDS CLI](https://github.com/alphgov/gds-cli) to assume a role in the right account
    ```shell
   gds aws forms-dev-admin --shell
    ```
2. Invoke `make` like

    ```shell
    make dev forms/forms-runner apply
    ```
    with the environment, deployment/root, and action (`init`, `plan`, or `apply`) in that order


> [!TIP]
> If you need to invoke Terraform directly, you should look at what arguments the Makefile is providing

> [!TIP]
> You can get proper tab completion for the Makefile by sourcing the `./support/makefile_completion.(ba|z)sh` file, at the root of this repository, in your shell profile.

### Maintaining separate environments
> [!NOTE]
> This section does not apply to the `deploy` deployment, because it is a singular environment.

Our Terraform deployments are structured to accept the differences between environments as Terraform variables defined in the `inputs.tf` file of each deployment, and their distinct values are defined in a set of `*.tfvars` files in the `tfvars/` directories.

### Deployment order and dependencies

The following provides a high-level overview of the deployments and in which order they should be applied if starting from scratch. Some modules contain a `README.md` which should be referenced for more specific instructions.

#### Development, Staging or Production Environment
In the unlikely event of needing to recreate an entire GOV.UK Forms environment the following order should be followed.
1. `forms/account` root should be applied to ready the AWS account. This will configure engineer access, and create a new Route53 hosted zone.
2. update the `production` vars file in the `forms/account` root with the nameservers from the previous step, so that the domain is correctly delegated
3. `forms/environment` to create the networking and common components for each GOV.UK Forms application.
4. `forms/pipelines` to deploy the pipelines for the environment
5. `forms/rds` to deploy the database needed for the applications
6. `forms/redis` to deploy the Redis cache needed for the applications
7. `forms/forms-{admin,product-page,runner}` to perform the first-time deployment of the applications. This is a manual step in the first instance because we need to supply a container image URI. After the first deployment, Terraform can look up the currently running container and maintain that image URI.

At this point the pipelines in the environment can be triggered which will deploy everything else.

#### Deploy Environment
To recreate the `deploy` environment, apply the following roots:
1. `engineer-access` to grant access to engineers to perform the following. If necessary ask an AWS admin to create a bootstrap role to provide authorization to apply the `engineer-access` deployment.
2. `account` to ensure the account is configured correctly.
3. `ecr` to create the ECR repositories that store the Docker images used by the ECS services in each environment.
4. `coordination` to allow the `deploy` environment to coordinate the deployments of other environments.
5. `forms-admin-pipeline` and `forms-runner-pipeline` to create the CodePipeline pipelines and CodeBuild projects.


### DNS For GOV.UK Forms

The `forms.service.gov.uk` domain is delegated to a Route53 Hosted Zone in our production environment. The `production` configuration of the `forms/account` root manages records to delegate the `dev.`, `staging.`, and `research.` subdomains to Route53 Hosted Zones in their respective environments. This is achieved by creating `NS` records within the production Hosted Zone which point to the name server addresses output when applying the `forms/account` root in each environment.


### Renovate

Dependabot keeps actions, bundler, npm and the Terraform providers up to date. [Renovate](https://docs.renovatebot.com/) handles the pins that are duplicated across files or repos and have to move together: Ruby, Alpine, Terraform, the tool versions and the pre-commit hooks. The shared rules are in `.github/renovate-shared.json5`, and each repo extends them with `github>govuk-forms/forms-deploy//.github/renovate-shared.json5`.

Renovate runs as the `renovate` CodeBuild project in the deploy account, defined by `modules/renovate` and called from the `deploy/tools` root. Logs are in the `/aws/codebuild/renovate` log group.

#### Runs

Every request for a run is a row in the `renovate-runs` DynamoDB table, one row per repo. EventBridge asks for a full run of every repo on `renovate_schedule`. The repos are the ones the GitHub App is installed on, read from GitHub and kept for five minutes. A repo the App is removed from stops starting, and an archived one is skipped. The `renovate-orchestrator` Lambda starts a build for each repo that has a request waiting and no build running, up to `concurrent_builds` (1 by default). Starting a repo is a conditional update, so two invocations at once can't start it twice.

A repo holds its place until its build ends. CodeBuild's state change event releases it and invokes the orchestrator, which starts whatever is waiting. A sweep every five minutes does the same in case an event was missed, and a lease a little longer than the build timeout frees a repo whose build died without a report. Any number of requests for a repo while it waits or runs collapse into one more run, and a full request wins over an event one. Each build has its own CodeBuild cache under `renovate/<owner>/<repo>`, and Renovate writes each repo's repository cache to its own object under `repository-cache/`, so repos can run side by side.

A full run may open new pull requests. An event run only keeps existing pull requests up to date. It sets Renovate's global `force` option to `{"dependencyDashboardApproval": true}`, so a new branch waits for a tick on the dashboard, and a tick still creates it. These two names are ours: Renovate already uses `full` for `mode` and `dryRun`. The run type changes nothing a pull request shows.

`support/renovate-runs.sh` controls the runner. Run it through `gds aws` with a profile that may invoke the orchestrator, for example `gds aws forms-dev-admin -- support/renovate-runs.sh status`. `status` shows whether the runner is suspended and each repo's pending request and build. `run [repo|all] [full|event]` asks for a run. `suspend` stops anything starting, for example while GitHub is having problems, and `resume` starts again. Requests made while it is suspended are kept and run on resume, and builds already running finish normally. The `renovate-left-suspended` alarm fires if it is left suspended for a day.

Don't start a build in CodeBuild directly: it needs the repo and token that the orchestrator provides. The Lambda tests are in `infra/modules/renovate/tests` and run in CI, or with `node --test 'infra/modules/renovate/tests/*.test.js'`.

The module's `dry_run` variable defaults to `full`: Renovate logs what it would do and opens no branches or pull requests. Set `dry_run = null` in `deploy/tools/renovate.tf` to run it for real.

Renovate keeps two caches in the module's S3 bucket. The package cache (lookup results and release notes) is a directory that CodeBuild archives between builds. The repository cache is written by Renovate itself, one object per repo under `repository-cache/`. A build that fails contributes nothing to the package cache, and a cold run after any change of cache prefix is slow.

The runner lets a repo's config run exactly one command: `support/update-hcl2json-sha.sh`, which Renovate runs after bumping `HCL2JSON_VERSION` to write the matching `HCL2JSON_SHA256` into the same commit. The script comes from the repo being built, so the build must hold nothing a hostile repo could use beyond that repo. It holds one installation token, scoped to the repo and valid for an hour. The App's private key is only ever read by the orchestrator. The allow-list is global to the runner, and the build role can still write any repo's cache in the bucket and read the other repos' tokens while they are in their hour.

#### Logs and metrics

Renovate logs one JSON object per line at debug level. Metric filters turn the build log into metrics in the `Renovate` namespace: `LogErrors` and `LogWarnings`, and, per repository, `PullRequestsCreated`, `PullRequestsUpdated` and `AbandonedDependencies`. The `renovate-log-errors` alarm notifies the failure topic when a run logs an error, which a build that still succeeds would not report. A dependency counts as abandoned when its last release is more than a year old, and Renovate only logs it, so the metric is the way to see it.

#### The GitHub App

Renovate signs in as an organisation-owned GitHub App, because pull requests opened with a workflow's own token don't trigger CI. The orchestrator mints an installation token for each build, limited to the one repo, and leaves it in a SecureString parameter under `/renovate/token/<owner>/<repo>` that the build reads as `RENOVATE_TOKEN`. That keeps it out of the build's record and CloudTrail. A build that queues for longer than its `queued_timeout` of 15 minutes is dropped, so that it can't start with an expired token.

The App needs these repository permissions: Contents, Issues, Pull requests, Workflows, Checks and Commit statuses (read and write), and Metadata and Dependabot alerts (read). Install it only on the repos Renovate runs against.

Terraform creates the two SSM parameters with a dummy value. Set the real values by hand:

```sh
aws ssm put-parameter --name /renovate/github-app-id --type SecureString --overwrite --value "<app id>"
aws ssm put-parameter --name /renovate/github-app-private-key --type SecureString --overwrite --value file://private-key.pem
```

#### Adding a repo

1. Install the GitHub App on the repo. That is all the runner needs, so there is nothing to change in Terraform, and removing the App from a repo takes it out again.
2. Add a `renovate.json5` to the repo that extends the shared preset.

Until `dry_run` is set to null in `deploy/tools/renovate.tf`, a new repo only gets dry runs.

### Linting and Static Analysis

[pre-commit](https://pre-commit.com/) runs checks on the Terraform code each time a developer runs `git commit`. The checks are defined within `forms-deploy/pre-commit-config.yaml` and include the following:
- [Terraform format](https://developer.hashicorp.com/terraform/cli/commands/fmt)
- [Checkov static analysis](https://www.checkov.io/)

Each developer working on the Terraform must install pre-commit and initialize it for this repo along with installing the necessary binaries to run the checks, for example `checkov`. Follow the instructions at the links above for guidance.

A Github Action Workflow runs `checkov` on the Terraform files within this repo on each PR. It is defined within `forms-deploy/.github/workflows/infra-ci.yml`.
