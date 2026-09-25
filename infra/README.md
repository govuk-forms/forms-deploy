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

The `forms.service.gov.uk` domain is delegated to a Route53 Hosted Zone in our production environment. The `production` configuration of the `forms/account` root manages records to delegate the `dev.` and `staging.` subdomains to Route53 Hosted Zones in their respective environments. This is achieved by creating `NS` records within the production Hosted Zone which point to the name server addresses output when applying the `forms/account` root in each environment.

The `forms.internal.digital.gov.uk` domain follows the same pattern. It is delegated from the GDS `internal.digital.gov.uk` zone to a Route53 Hosted Zone in our production environment, and the `production` configuration of the `forms/account` root delegates the `dev.` and `staging.` subdomains to Hosted Zones in those environments via `internal_dns_delegation_records`. The name servers for each environment's zone are available from the `internal_digital_name_servers` output of the `forms/account` root.


### Linting and Static Analysis

[pre-commit](https://pre-commit.com/) runs checks on the Terraform code each time a developer runs `git commit`. The checks are defined within `forms-deploy/pre-commit-config.yaml` and include the following:
- [Terraform format](https://developer.hashicorp.com/terraform/cli/commands/fmt)
- [Checkov static analysis](https://www.checkov.io/)

Each developer working on the Terraform must install pre-commit and initialize it for this repo along with installing the necessary binaries to run the checks, for example `checkov`. Follow the instructions at the links above for guidance.

A Github Action Workflow runs `checkov` on the Terraform files within this repo on each PR. It is defined within `forms-deploy/.github/workflows/infra-ci.yml`.
