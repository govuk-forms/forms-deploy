ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
CODEBUILD_CI ?= false
SHELL=/usr/bin/env bash

##
# Environment targets
##
target_environment_set:
	$(if ${TARGET_ENVIRONMENT},,$(error Target environment is not set. Try adding an environment target, such as 'dev' or 'production', before the final target. (e.g. 'make dev apply')))
	@true

.PHONY: dev development
dev development:
	$(eval export TARGET_ENVIRONMENT = dev)
	@true

.PHONY: staging
staging:
	$(eval export TARGET_ENVIRONMENT = staging)
	@true

.PHONY: prod production
prod production:
	$(eval export TARGET_ENVIRONMENT = production)
	@true

.PHONY: deploy
deploy:
	$(eval export TARGET_ENVIRONMENT = deploy)
	@true

.PHONY: integration
integration:
	$(eval export TARGET_ENVIRONMENT = integration)
	@true

##
# Terraform root targets
#
# You may be tempted to simplify "-mindepth 1 -maxdepth 1" to "-depth 1" but this will only work on developer machines,
# and will break in CI/CD environments which use a newer version of find which has deprecate "-depth N".
##
FORMS_TF_ROOTS = $(shell cd infra/deployments; find forms -mindepth 1 -maxdepth 1 -type d -not -path "*/tfvars" -not -path "*/.terraform")
DEPLOY_TF_ROOTS = $(shell cd infra/deployments; find deploy -mindepth 1 -maxdepth 1 -type d -not -path "*/tfvars" -not -path "*/.terraform")
INTEGRATION_TF_ROOTS = $(shell cd infra/deployments; find integration -mindepth 1 -maxdepth 1 -type d -not -path "*/tfvars" -not -path "*/.terraform")

target_tf_root_set:
	$(if ${TARGET_TF_ROOT},,$(error Target Terraform root is not set. Try adding an Terraform root target before the final target. Terraform root targets are directories relative to 'infra/deployments/', such as 'forms/dns'.))
	@true

# "$(@:forms/%=%)" is removing the "forms/" prefix from the chosen root.
# The prefix is useful for a user, but when scripting we want only the
# name of the directory.
$(FORMS_TF_ROOTS):
	$(eval export TARGET_DEPLOYMENT = forms)
	$(eval export TARGET_TF_ROOT = $(@:forms/%=%))
	@true

$(DEPLOY_TF_ROOTS):
	$(eval export TARGET_DEPLOYMENT = deploy)
	$(eval export TARGET_TF_ROOT = $(@:deploy/%=%))
	@true

$(INTEGRATION_TF_ROOTS):
	$(eval export TARGET_DEPLOYMENT = integration)
	$(eval export TARGET_TF_ROOT = $(@:integration/%=%))
	@true

##
# Action targets
##
aws_credentials_available:
	@if [ "${CODEBUILD_CI}" = false ]; then \
		if [ -z "${AWS_SESSION_TOKEN}" ]; then \
		 	>&2 echo "'AWS_SESSION_TOKEN' was not found among your environment variables. Make sure you've assumed a role in the AWS account you're targetting."; \
		 	false; \
	 	fi; \
 	else \
 		>2& echo "CodeBuild detected. Assuming credentials are present in the environment."; \
 	fi;
	@true

not_ci:
	@if [ "${CODEBUILD_CI}" = true ]; then \
		>&2 echo "This target should not be run from a CI system. It may require human intervention"; \
		false; \
	fi;
	@true

only_dev: target_environment_set
	@if [ "$(TARGET_ENVIRONMENT)" != "dev" ]; then \
		>&2 echo "Error: This operation is only available for the dev environment. Use 'make dev ...' instead."; \
		false; \
	fi
	@true

show_info:
	@echo ""
	@echo "========[Terraform target information]"
	@echo "=> Target environment:     $${TARGET_ENVIRONMENT}"
	@echo "=> Target deployment:      $${TARGET_DEPLOYMENT}"
	@echo "=> Terraform root:         $${TARGET_TF_ROOT}"
	@if env | grep "TF_VAR_" >/dev/null 2>&1; then \
  		echo "=> Overridden Terraform variables:"; \
  		env | grep TF_VAR_ | sed 's/^TF_VAR_//g' | xargs printf "\t%s\n"; \
  	fi
	@echo "========"
	@echo ""

.PHONY: init
init: target_environment_set target_tf_root_set aws_credentials_available show_info
	@./support/invoke-terraform.sh -a init -d "$${TARGET_DEPLOYMENT}" -e "$${TARGET_ENVIRONMENT}" -r "$${TARGET_TF_ROOT}"

.PHONY: plan
plan: init
	@./support/invoke-terraform.sh -a plan -d "$${TARGET_DEPLOYMENT}" -e "$${TARGET_ENVIRONMENT}" -r "$${TARGET_TF_ROOT}"

.PHONY: apply
apply: init
	@./support/invoke-terraform.sh -a apply -d "$${TARGET_DEPLOYMENT}" -e "$${TARGET_ENVIRONMENT}" -r "$${TARGET_TF_ROOT}"

.PHONY: validate
validate: init
	@./support/invoke-terraform.sh -a validate -d "$${TARGET_DEPLOYMENT}" -e "$${TARGET_ENVIRONMENT}" -r "$${TARGET_TF_ROOT}"

.PHONY: unlock
unlock: target_environment_set target_tf_root_set aws_credentials_available show_info
	$(if ${LOCK_ID},,$(error Must set lock id with LOCK_ID="lock_id" at the end of this target))
	@./support/invoke-terraform.sh -a unlock -d "$${TARGET_DEPLOYMENT}" -e "$${TARGET_ENVIRONMENT}" -r "$${TARGET_TF_ROOT}" -l "$${LOCK_ID}"

tf_shell: init
	@./support/invoke-terraform.sh -a shell -d "$${TARGET_DEPLOYMENT}" -e "$${TARGET_ENVIRONMENT}" -r "$${TARGET_TF_ROOT}"

.PHONY: forms_apply_all
forms_apply_all: target_environment_set not_ci aws_credentials_available
	$(eval export TARGET_DEPLOYMENT = forms)
	@./infra/scripts/apply-roots-in-order.sh

.PHONY: deploy_apply_all
deploy_apply_all: not_ci aws_credentials_available
	$(eval export TARGET_DEPLOYMENT = deploy)
	$(eval export TARGET_ENVIRONMENT = deploy)
	@./infra/scripts/apply-roots-in-order.sh

.PHONY: integration_apply_all
integration_apply_all: not_ci aws_credentials_available
	$(eval export TARGET_DEPLOYMENT = integration)
	$(eval export TARGET_ENVIRONMENT = integration)
	@./infra/scripts/apply-roots-in-order.sh

.PHONY: deployer_role
deployer_role: only_dev not_ci aws_credentials_available
	$(eval ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text))
	$(eval ROLE_ARN := arn:aws:iam::$(ACCOUNT_ID):role/deployer-$(TARGET_ENVIRONMENT))
	@echo "Assuming role $(ROLE_ARN)"
	$(eval CREDS := $(shell aws sts assume-role --role-arn "$(ROLE_ARN)" --role-session-name "LocalDeployerSession" --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text))
	$(eval export AWS_ACCESS_KEY_ID := $(word 1,$(CREDS)))
	$(eval export AWS_SECRET_ACCESS_KEY := $(word 2,$(CREDS)))
	$(eval export AWS_SESSION_TOKEN := $(word 3,$(CREDS)))
	@echo "AWS credentials updated for $(TARGET_ENVIRONMENT) environment"


##
# Terraform Plugin Cache Targets
##
.PHONY: clear-tf-plugin-cache
clear-tf-plugin-cache:
	@./support/invoke-terraform.sh -a clear-plugin-cache -d dummy -e dummy

##
# Pipeline targets
##

.PHONY: trigger_terraform_pipeline
trigger_terraform_pipeline: target_environment_set
	$(if ${SHA},,$(error Must set SHA with SHA="sha" at the end of this target))
	@aws codepipeline start-pipeline-execution \
		--name "apply-forms-terraform-$(TARGET_ENVIRONMENT)" \
		--source-revisions actionName=get-forms-deploy,revisionType=COMMIT_ID,revisionValue="${SHA}" \
		--query "pipelineExecutionId" --output text


##
# Rotate aws access keys targets
##
.PHONY: rotate_aws_auth0_access_keys
rotate_aws_auth0_access_keys: target_environment_set
	@./support/rotate-aws-auth0-access-keys.sh -e "$${TARGET_ENVIRONMENT}"

##
# Utility targets
##
.PHONY: generate-completion-word-list
generate-completion-word-list:
	@$(MAKE) -qprRn -f "Makefile" : 2>/dev/null | grep -E "^([[:alnum:][:punct:]]+)\:.*$$" | cut -d ':' -f 1 | sed '/^ *$$/d'

.PHONY: fmt
fmt:
	$(if ${CHANGED_FILES}, $(eval CHANGED_FILES_ARGS := $(foreach f,$(CHANGED_FILES),$(f))),$(eval CHANGED_FILES_ARGS := --recursive infra/))
	terraform fmt $(CHANGED_FILES_ARGS)

.PHONY: lint
lint: checkov tflint spec lint_ruby

.PHONY: lint_ruby
lint_ruby:
	bundle install
	bundle exec rubocop

.PHONY: checkov
checkov:
	$(if ${CHANGED_FILES}, $(eval CHANGED_FILES_ARGS := --file $(foreach f,$(CHANGED_FILES),$(f))), $(eval CHANGED_FILES_ARGS := --directory infra/))
	checkov --external-checks-dir infra/checkov/ --framework terraform --quiet --download-external-modules false $(CHANGED_FILES_ARGS)

.PHONY: spec
spec:
	(cd infra; bundle install; bundle exec rspec;)
	(cd support/pipeline-visualiser; bundle install; bundle exec rspec;)
	(cd infra/deployments/forms/pipelines/pipeline-invoker; bundle install; bundle exec rspec;)

.PHONY: tflint
tflint: tflint_init tflint_modules tflint_deploy tflint_forms tflint_integration

.PHONY: tflint_init
tflint_init:
	tflint --init

.PHONY: tflint_modules
tflint_modules:
	@# some rules are disabled because modules don't
	@# need to define the things those rules check for
	@mods='$(filter infra/modules/%,$(CHANGED_FILES))'; \
	if [ -z "$$mods" ]; then \
	  echo "No module changes; skipping tflint_modules"; \
	else \
	  filters='$(patsubst infra/modules/%,--filter=%,$(filter infra/modules/%,$(CHANGED_FILES)))'; \
	  tflint --chdir=infra/modules --recursive --config "$$(pwd)/.tflint.hcl" \
	    --disable-rule "terraform_required_version" \
	    --disable-rule "terraform_required_providers" \
	    $(TFLINT_ARGS) $$filters; \
	fi

.PHONY: tflint_deploy
tflint_deploy:
	@# Pick only roots that have changes. If no CHANGED_FILES, lint all.
	$(eval ROOTS_TO_LINT := $(if $(strip $(CHANGED_FILES)), \
		$(sort $(foreach r,$(DEPLOY_TF_ROOTS), \
			$(if $(filter infra/deployments/$(r)/%,$(CHANGED_FILES)),$(r)) \
		)), \
		$(DEPLOY_TF_ROOTS)))

	$(if $(strip $(ROOTS_TO_LINT)),,$(info No changed deploy roots; skipping tflint_deploy))

	$(foreach root,$(ROOTS_TO_LINT), \
		$(eval _CHANGED := $(filter infra/deployments/$(root)/%,$(CHANGED_FILES))) \
		$(eval _FILTERS := $(patsubst infra/deployments/$(root)/%,--filter=%,$(_CHANGED))) \
		tflint --chdir="infra/deployments/$(root)" --config "$$(pwd)/.tflint.hcl" $(TFLINT_ARGS) $(_FILTERS) ; \
	)

.PHONY: tflint_forms
tflint_forms:
	@# Lint only forms roots touched by CHANGED_FILES; if none given, lint all
	$(eval ROOTS_TO_LINT := $(if $(strip $(CHANGED_FILES)), \
		$(sort $(foreach r,$(FORMS_TF_ROOTS), \
			$(if $(filter infra/deployments/$(r)/%,$(CHANGED_FILES)),$(r)) \
		)), \
		$(FORMS_TF_ROOTS)))

	$(if $(strip $(ROOTS_TO_LINT)),,$(info No changed forms roots; skipping tflint_forms))

	$(foreach root,$(ROOTS_TO_LINT), \
		$(eval _CHANGED := $(filter infra/deployments/$(root)/%,$(CHANGED_FILES))) \
		$(eval _FILTERS := $(patsubst infra/deployments/$(root)/%,--filter=%,$(_CHANGED))) \
		tflint --chdir="infra/deployments/$(root)" --config "$$(pwd)/.tflint.hcl" $(TFLINT_ARGS) \
			--var-file="$$(pwd)/infra/deployments/forms/tfvars/production.tfvars" \
			--var-file="$$(pwd)/infra/deployments/forms/account/tfvars/backends/production.tfvars" \
			$(_FILTERS) ; \
	)

.PHONY: tflint_integration
tflint_integration:
	@# Lint only integration roots touched by CHANGED_FILES; if none given, lint all
	$(eval ROOTS_TO_LINT := $(if $(strip $(CHANGED_FILES)), \
		$(sort $(foreach r,$(INTEGRATION_TF_ROOTS), \
			$(if $(filter infra/deployments/$(r)/%,$(CHANGED_FILES)),$(r)) \
		)), \
		$(INTEGRATION_TF_ROOTS)))

	$(if $(strip $(ROOTS_TO_LINT)),,$(info No changed integration roots; skipping tflint_integration))

	$(foreach root,$(strip $(ROOTS_TO_LINT)), \
		$(eval _CHANGED := $(filter infra/deployments/$(root)/%,$(CHANGED_FILES))) \
		$(eval _FILTERS := $(patsubst infra/deployments/$(root)/%,--filter=%,$(_CHANGED))) \
		tflint --chdir="infra/deployments/$(root)" --config "$$(pwd)/.tflint.hcl" $(TFLINT_ARGS) \
			--var-file="$$(pwd)/infra/deployments/integration/tfvars/integration.tfvars" \
			--var-file="$$(pwd)/infra/deployments/integration/tfvars/backends/integration.tfvars" \
			$(_FILTERS) ; \
	)

.PHONY: current_sha
current_sha:
	$(eval export SHA=$(shell git rev-parse HEAD))
	@true

##
# Help text
# Keep it at the bottom so it can grow as necessary without cluttering everything above.
# The formatting may look off in this file, but it should be correct when written to stdout.
##
define help_usage_text
PURPOSE
	This Makefile has two general use cases:
	1. Running Terraform
	2. Running tasks

RUNNING TERRAFORM
	To run Terraform code use the command

		make <ENV> <ROOT> <ACTION>

	where <ENV> is an environment name, <ROOT> is a Terraform root,
	and <ACTION> is an action to take with the Terraform code.

	The valid options for <ENV>, <ROOT>, and <ACTION> are documented below.

	You can also apply all of the Terraform for a GOV.UK Forms environment
	in the correct order by running

		make <ENV> forms_apply_all

	where <ENV> is an environment name.

	To run the Terraform code, you will need to have credentials for the
	relevant environment. You should use GDS CLI to get them. For example

		gds aws forms-dev-readonly -- make dev forms/environment plan

RUNNING OTHER TASKS
	To run other tasks use the command

		make <TASK>

	where <TASK> is one of the other tasks documented below.

endef
export help_usage_text

define help_environments
ENVIRONMENTS
	deploy		Central account for things like image repositories, and
			image building pipelines.
			n.b. deployments do not take place in this account. The
			name is a legacy from when they did.

	integration	Account for running integration pieces, such as performance
			tests and review apps.

	dev/development		The development environment
	staging			The staging environment
	prod/production		The production environment

endef
export help_environments

define help_actions
ACTIONS
	validate	Validate the syntax of the Terraform files
	init		Initialise the Terraform root
	plan		Run a Terraform plan
	apply		Apply the Terraform
	unlock		Forcibly release the lock with the given lock id

	forms_apply_all		Apply all of the Terraform for a GOV.UK Forms
				environment in the correct order.

	deploy_apply_all	Apply all of the Terraform for the deploy
				deployment in the correct order.

	integration_apply_all	Apply all of the Terraform for the integration
				deployment in the correct order.

				For all *_apply_all targets:
				Set RESUME_FROM_CHECKPOINT=true to start the run
				from where the last run ended. Useful when iterating.

endef
export help_actions

define help_tasks
TASKS
	help		This help text
	fmt		Automatically format all Terraform code
	lint		Run all linting tasks
	lint_ruby	Run Rubocop against all Ruby code
	spec		Run Rspec tests against Ruby and Terraform code

	checkov		Run Checkov (a Terraform linter) against all Terraform code
			Checkov is evaluating how we configure things in AWS.

	tflint		Run TFLint (a Terraform linter) against all Terraform code.
			TFLint is evaluating the quality of our Terraform code.
endef
export help_tasks

.PHONY: help
help:
	@echo "$$help_usage_text"
	@echo "$$help_environments"
	@echo "ROOTS"
	@for r in $(sort $(FORMS_TF_ROOTS) $(DEPLOY_TF_ROOTS)); do \
  		printf "\t%s\n" $$r; \
	done; \
	echo "" \

	@echo "$$help_actions"
	@echo "$$help_tasks"
	@true
