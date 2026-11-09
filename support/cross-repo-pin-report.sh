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
# The sed expression prints the version. Files that don't exist in a repo show as "-",
# and a file that couldn't be read shows as "?", which leaves the row's comparison open.
# The Dockerfile expressions read both the literal FROM line and the ARG form.
ROWS=(
  '.ruby-version|.ruby-version|.ruby-version|s/^ *([0-9][0-9.]*) *$/\1/p'
  'Ruby in Dockerfile|support/pipeline-visualiser/Dockerfile|Dockerfile|s/^(FROM ruby:|ARG RUBY_VERSION=)([0-9.]+).*/\2/p'
  'Alpine in Dockerfile|support/pipeline-visualiser/Dockerfile|Dockerfile|s/^(FROM ruby:[0-9.]+-alpine|ARG ALPINE_VERSION=)([0-9.]+).*/\2/p'
  '.nvmrc||.nvmrc|s/^ *v?([0-9][0-9.]*) *$/\1/p'
  '.terraform-version|.terraform-version|.review_apps/.terraform-version|s/^ *([0-9][0-9.]*) *$/\1/p'
  'Terraform required_version|infra/shared/versions.tf|.review_apps/site.tf|s/^ *required_version *= *"(~> )?([0-9.]+)".*/\2/p'
)

errors="$(mktemp)"
trap 'rm -f "${errors}"' EXIT

pin() {
  local repo="$1" path="$2" expression="$3" content="" encoded=""

  if [[ -n "${path}" ]]; then
    # A 404 just means the repo doesn't have the file. Anything else is a read
    # that failed, and mustn't look like a repo with no pin.
    if ! encoded="$(gh api "repos/${ORG}/${repo}/contents/${path}" --jq .content 2>"${errors}")"; then
      if ! grep -q 'HTTP 404' "${errors}"; then
        echo "?"
        return
      fi
    elif ! content="$(base64 -d <<<"${encoded}" 2>/dev/null)"; then
      echo "?"
      return
    fi
  fi

  local version
  version="$(sed -nE "${expression}" <<<"${content}" | head -n 1 || true)"
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
unknown=0
for row in "${ROWS[@]}"; do
  IFS='|' read -r label deploy_path app_path expression <<<"${row}"

  line="| ${label} |"
  versions=()
  unreadable=()
  detail=""
  for repo in "${REPOS[@]}"; do
    path="${app_path}"
    [[ "${repo}" == "forms-deploy" ]] && path="${deploy_path}"

    version="$(pin "${repo}" "${path}" "${expression}")"
    line+=" ${version} |"
    detail+="${repo}=${version}, "
    if [[ "${version}" == "?" ]]; then
      unreadable+=("${repo}")
    elif [[ "${version}" != "-" ]]; then
      versions+=("${version}")
    fi
  done

  same="yes"
  if [[ "${#versions[@]}" -gt 0 && "$(printf '%s\n' "${versions[@]}" | sort -u | wc -l)" -gt 1 ]]; then
    same="no"
    drifted=$((drifted + 1))
    echo "::warning title=Pin differs between repos::${label}: ${detail%, }"
  fi

  if [[ "${#unreadable[@]}" -gt 0 ]]; then
    unknown=$((unknown + 1))
    echo "::warning title=Pin could not be read::${label}: ${unreadable[*]}"
    [[ "${same}" == "yes" ]] && same="unknown"
  fi

  echo "${line} ${same} |" >>"${summary}"
done

echo "${drifted} of ${#ROWS[@]} pins differ between repos, and ${unknown} could not be compared because a file couldn't be read."
