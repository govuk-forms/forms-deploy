#!/usr/bin/env bash
set -euo pipefail

# Reports the Ruby, Alpine, Node and Terraform pins in each GOV.UK Forms repo
# side by side, and warns about any that differ. It reports only: a pin that
# differs here may be mid-update, so it never fails.
#
# Needs `gh` authenticated (the repos are public, so any token will do).

ORG="govuk-forms"
REPOS=(forms-admin forms-deploy forms-e2e-tests forms-product-page forms-runner)

# Each row is: label | file in forms-deploy | file in the app repos | sed expression
# The sed expression prints the version. Files that don't exist in a repo show as "-".
# The Dockerfile expressions read both the literal FROM line and the ARG form.
ROWS=(
  '.ruby-version|.ruby-version|.ruby-version|s/^ *([0-9][0-9.]*) *$/\1/p'
  'Ruby in Dockerfile|support/pipeline-visualiser/Dockerfile|Dockerfile|s/^(FROM ruby:|ARG RUBY_VERSION=)([0-9.]+).*/\2/p'
  'Alpine in Dockerfile|support/pipeline-visualiser/Dockerfile|Dockerfile|s/^(FROM ruby:[0-9.]+-alpine|ARG ALPINE_VERSION=)([0-9.]+).*/\2/p'
  '.nvmrc||.nvmrc|s/^ *v?([0-9][0-9.]*) *$/\1/p'
  '.terraform-version|.terraform-version|.review_apps/.terraform-version|s/^ *([0-9][0-9.]*) *$/\1/p'
  'Terraform required_version|infra/shared/versions.tf|.review_apps/site.tf|s/^ *required_version *= *"(~> )?([0-9.]+)".*/\2/p'
)

pin() {
  local repo="$1" path="$2" expression="$3" content=""

  if [[ -n "${path}" ]]; then
    # A 404 just means the repo doesn't have the file.
    content="$(gh api "repos/${ORG}/${repo}/contents/${path}" --jq .content 2>/dev/null | base64 -d 2>/dev/null || true)"
  fi

  local version
  version="$(sed -nE "${expression}" <<<"${content}" | head -n 1)"
  echo "${version:--}"
}

summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

{
  header="| Pin |"
  divider="| --- |"
  for repo in "${REPOS[@]}"; do
    header+=" ${repo} |"
    divider+=" --- |"
  done
  echo "${header} Same |"
  echo "${divider} --- |"
} >>"${summary}"

drifted=0
for row in "${ROWS[@]}"; do
  IFS='|' read -r label deploy_path app_path expression <<<"${row}"

  line="| ${label} |"
  versions=()
  detail=""
  for repo in "${REPOS[@]}"; do
    path="${app_path}"
    [[ "${repo}" == "forms-deploy" ]] && path="${deploy_path}"

    version="$(pin "${repo}" "${path}" "${expression}")"
    line+=" ${version} |"
    detail+="${repo}=${version}, "
    [[ "${version}" != "-" ]] && versions+=("${version}")
  done

  same="yes"
  if [[ "$(printf '%s\n' "${versions[@]}" | sort -u | wc -l)" -gt 1 ]]; then
    same="no"
    drifted=$((drifted + 1))
    echo "::warning title=Pin differs between repos::${label}: ${detail%, }"
  fi

  echo "${line} ${same} |" >>"${summary}"
done

echo "${drifted} of ${#ROWS[@]} pins differ between repos."
