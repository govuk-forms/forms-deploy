locals {
  # Developers must have an IAM user within the gds-users account before they
  # can be given access to the GOV.UK Forms AWS accounts. To request an IAM user:
  # https://gds-request-an-aws-account.cloudapps.digital/user

  # Admin access to the deploy, staging, and production environments should
  # only be provided when needed.

  # GOV.UK Forms developers that have completed onboarding and support the
  # platform can have the support role

  # All GOV.UK Forms developers can have readonly access to
  # the staging and production environments.

  # All GOV.UK Forms developers can have admin access to the development
  # and user research accounts.

  accounts = ["deploy", "staging", "production", "development", "integration"]
  roles    = ["admin", "support", "readonly"]

  users = {
    "alice.carr" = {
      deploy      = "admin" # Admin whilst setting up the deploy account
      staging     = "admin" # Required whilst setting up environments
      production  = "admin" # Required whilst setting up environments
      development = "admin"
      integration = "admin"
    },
    "catalina.garcia" = {
      deploy      = "admin" # Admin to apply changes to pipelines until we have pipelines for our pipelines
      staging     = "admin" # Required whilst setting up environments
      production  = "admin" # Required whilst setting up environments
      development = "admin"
      integration = "admin"
    },
    "david.biddle" = {
      deploy      = "admin"
      staging     = "admin"
      production  = "admin"
      development = "admin"
      integration = "readonly"
    },
    "kelvin.gan" = {
      deploy      = "admin" # Feature Team Tech lead
      staging     = "admin" # Feature Team Tech lead
      production  = "admin" # Feature Team Tech lead
      development = "admin"
      integration = "readonly"
    },
    "laurence.debruxelles" = {
      deploy      = "admin" # We are short of SREs
      staging     = "admin"
      production  = "admin"
      development = "admin"
      integration = "admin"
    },
    "max.fitzhugh" = {
      deploy      = "readonly"
      staging     = "readonly"
      production  = "readonly"
      development = "readonly"
      integration = "readonly"
    },
    "samuel.culley" = {
      deploy      = "admin"
      staging     = "admin"
      production  = "admin"
      development = "admin"
      integration = "readonly"
    },
    "sarah.young1" = {
      deploy      = "admin"
      staging     = "admin"
      production  = "admin"
      development = "admin"
      integration = "admin"
    },
    "sean.rankine" = {
      deploy      = "admin" # Sean is our Lead Dev and has also worked as a Sr SRE.
      staging     = "admin"
      production  = "admin"
      development = "admin"
      integration = "admin"
    },
    "stephen.daly" = {
      deploy      = "admin"
      staging     = "admin"
      production  = "admin"
      development = "admin"
      integration = "readonly"
    },
    "tom.iles" = {
      deploy      = "admin"
      staging     = "admin"
      production  = "admin"
      development = "admin"
      integration = "readonly"
    },
    "tom.whitwell" = {
      deploy      = "admin"
      staging     = "admin"
      production  = "admin"
      development = "admin"
      integration = "admin"
    },
  }
}
