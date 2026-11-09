#!/usr/bin/env bash
set -euo pipefail

GIT_DIR=$(git rev-parse --show-toplevel)
SHARED_DIR="${GIT_DIR}/infra/shared"

# Global variable for terraform version override
TF_VERSION="latest"

# Global variable for lock-only mode
LOCK_ONLY=false

# Function to check if a command is available
check_command() {
	local cmd="$1"
	command -v "$cmd" >/dev/null 2>&1 || {
		echo >&2 "$cmd is required but it's not installed. Aborting."
		exit 1
	}
}

# Function to get terraform version from versions.tf
get_terraform_version() {
	check_command "hcl2json"
	check_command "jq"
	hcl2json versions.tf | jq -r '.terraform[0].required_version'
}

# Function to get all providers using jq
get_all_providers() {
	check_command "hcl2json"
	check_command "jq"

	# Use jq to get all providers
	hcl2json versions.tf | jq -r '
    .terraform[0].required_providers[0] |
    to_entries[] |
    .value.source
  '
}

# Function to get provider info (source and version) for tracking changes
get_provider_info() {
	check_command "hcl2json"
	check_command "jq"

	# Use jq to get both source and version for all providers
	hcl2json versions.tf | jq -r '
    .terraform[0].required_providers[0] |
    to_entries[] |
    "\(.value.source)|\(.value.version)"
  '
}

# Function to update providers
update_providers() {
	check_command "tfupdate"
	pushd "$SHARED_DIR" >/dev/null || exit 1
	echo "Updating providers..."

	# Get provider info before update
	local provider_info_before
	readarray -t provider_info_before < <(get_provider_info)

	# Create associative array for before versions
	declare -A before_versions
	for info in "${provider_info_before[@]}"; do
		local source="${info%|*}"
		local version="${info#*|}"
		before_versions["$source"]="$version"
	done

	# Update each provider
	local providers
	readarray -t providers < <(get_all_providers)

	for provider in "${providers[@]}"; do
		echo "Updating provider: $provider"
		tfupdate provider "$provider" .
	done

	# Get provider info after update
	local provider_info_after
	readarray -t provider_info_after < <(get_provider_info)

	# Print version changes
	echo "Provider version changes:"
	for info in "${provider_info_after[@]}"; do
		local source="${info%|*}"
		local after_version="${info#*|}"
		local before_version="${before_versions[$source]}"

		if [[ "$before_version" != "$after_version" ]]; then
			echo "  $source: $before_version → $after_version"
		else
			echo "  $source: unchanged ($before_version)"
		fi
	done


	popd >/dev/null || exit 1
}

# Function to lock providers
lock_providers() {
	check_command "tfupdate"
	echo "Locking providers..."
	tfupdate lock -r \
		--platform linux_arm64 \
		--platform linux_amd64 \
		--platform darwin_arm64 \
		--platform darwin_amd64 \
		--platform windows_amd64 \
		-i infra/shared infra/
}

# Function to update terraform
update_terraform() {
	check_command "tfupdate"
	pushd "$SHARED_DIR" >/dev/null || exit 1
	echo "Updating terraform..."

	# Get the version before update
	local pre_version
	pre_version=$(get_terraform_version)

	# Run tfupdate with or without version parameter
	if [[ "$TF_VERSION" != "latest" ]]; then
		echo "Updating terraform to specific version: $TF_VERSION"
	fi
	# Recursive, so the roots with their own versions.tf move with the shared one
	tfupdate terraform --version "$TF_VERSION" -r "${GIT_DIR}/infra"

	# Get the version after update
	local post_version
	post_version=$(get_terraform_version)

	echo -n "$post_version" >"${GIT_DIR}/.terraform-version"

	# Print the update information
	if [[ "$pre_version" != "$post_version" ]]; then
		echo "Updated terraform from $pre_version to $post_version"
	else
		echo "Terraform version unchanged: $pre_version"
	fi
	popd >/dev/null || exit 1
}

# Command line parsing
while [[ $# -gt 0 ]]; do
	case $1 in
	--tf-version)
		TF_VERSION="$2"
		shift 2
		;;
	--lock-only)
		LOCK_ONLY=true
		shift
		;;
	*)
		echo "Usage: $0 [--tf-version VERSION] [--lock-only]"
		echo "  --tf-version VERSION  Set terraform to specific version (default: latest)"
		echo "  --lock-only           Only update provider locks, skip terraform and provider updates"
		echo "  (no args)             Update terraform, providers, and lock providers"
		exit 1
		;;
	esac
done

if [[ "$LOCK_ONLY" == "true" ]]; then
	echo "Running in lock-only mode..."
	lock_providers
else
	update_terraform
	update_providers
	lock_providers
fi
