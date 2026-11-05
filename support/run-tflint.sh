#!/usr/bin/env bash
#
# Runs tflint against our Terraform roots. `make tflint`, pre-commit and CI
# all call this.
#
# With no arguments, lints every root. With changed file paths, lints the
# roots and module directories containing them.
# Extra tflint arguments can be passed in TFLINT_ARGS.

set -euo pipefail

cd "$(dirname "$0")/.."

tflint --init

config="$(pwd)/.tflint.hcl"
changed=("$@")
failed=false

# A config change can affect every root.
for f in ${changed[@]+"${changed[@]}"}; do
  if [ "$f" = ".tflint.hcl" ]; then
    changed=()
    break
  fi
done

# touched DIR: true if no files were given, or one of them is under DIR
touched() {
  if [ "${#changed[@]}" -eq 0 ]; then
    return 0
  fi

  local f
  for f in "${changed[@]}"; do
    case "$f" in
      "$1"/*) return 0 ;;
    esac
  done
  return 1
}

# run_tflint DIR [TFLINT_ARG...]
run_tflint() {
  local dir="$1"
  shift

  echo "tflint: ${dir}"
  # shellcheck disable=SC2086 # TFLINT_ARGS is a space separated list
  tflint --chdir="$dir" --config "$config" "$@" ${TFLINT_ARGS:-} || failed=true
}

# lint_roots GROUP [TFLINT_ARG...]
lint_roots() {
  local group="$1" root
  shift

  while IFS= read -r root; do
    if touched "infra/deployments/${root}"; then
      run_tflint "infra/deployments/${root}" "$@"
    fi
  done < <(cd infra/deployments && find "$group" -mindepth 1 -maxdepth 1 -type d \
    -not -path "*/tfvars" -not -path "*/.terraform" | sort)
}

# Some rules don't apply because modules don't declare the things they check.
module_args=(
  --disable-rule terraform_required_version
  --disable-rule terraform_required_providers
)
if [ "${#changed[@]}" -eq 0 ]; then
  run_tflint infra/modules --recursive "${module_args[@]}"
else
  while IFS= read -r dir; do
    if [ -d "$dir" ]; then
      run_tflint "$dir" "${module_args[@]}"
    fi
  done < <(for f in "${changed[@]}"; do
    case "$f" in
      infra/modules/*) dirname "$f" ;;
    esac
  done | sort -u)
fi

lint_roots deploy

lint_roots forms \
  "--var-file=$(pwd)/infra/deployments/forms/tfvars/production.tfvars" \
  "--var-file=$(pwd)/infra/deployments/forms/account/tfvars/backends/production.tfvars"

lint_roots integration \
  "--var-file=$(pwd)/infra/deployments/integration/tfvars/integration.tfvars" \
  "--var-file=$(pwd)/infra/deployments/integration/tfvars/backends/integration.tfvars"

if [ "$failed" = true ]; then
  exit 1
fi
