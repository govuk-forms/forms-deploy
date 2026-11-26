#!/usr/bin/env bash
#
# Fails a Renovate pull request whose update hasn't met minimumReleaseAge, and
# passes every other pull request. The ruleset requires this check instead of
# renovate/stability-days, which only exists on Renovate's pull requests and
# leaves the rest waiting for it.
#
# Renovate sets no status on updates it can't date (ECR and ghcr images), and
# labels them no-release-date. Those pass without a status, because a person
# approved them on the dashboard. A status that is there still counts.
#
# Usage: check-renovate-release-age.sh REPO SHA HEAD_REF PR_AUTHOR [LABELS]
# LABELS is the pull request's label names, separated by commas.
#
# POLL_ATTEMPTS and POLL_SECONDS set how long to wait for the status, which
# Renovate sets a few seconds after it pushes.

set -euo pipefail

repo=${1:?usage: check-renovate-release-age.sh REPO SHA HEAD_REF PR_AUTHOR}
sha=${2:?}
head_ref=${3:?}
author=${4:?}
labels=${5:-}

context="renovate/stability-days"
attempts=${POLL_ATTEMPTS:-18}
seconds=${POLL_SECONDS:-10}

undated=false
case ",${labels}," in
*,no-release-date,*)
  undated=true
  attempts=1
  ;;
esac

# Puts the reason on the checks tab as well as in the log. Outside Actions the
# annotation is just a line of output.
explain() {
  local title=$1 detail=$2
  echo "::error title=${title}::${detail}"
  if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
    {
      echo "### ${title}"
      echo
      echo "${detail}"
    } >>"${GITHUB_STEP_SUMMARY}"
  fi
}

if [[ ${head_ref} != renovate/* || ${author} != *"[bot]" ]]; then
  echo "Not a Renovate pull request, so there is no release age to check."
  exit 0
fi

for ((attempt = 1; attempt <= attempts; attempt++)); do
  # Only a status set by the app that opened the pull request counts, and the
  # newest of those wins. The combined status endpoint leaves out who set each
  # status, so this reads the list, which is newest first and paginated: awk
  # keeps the first match across every page.
  state=$(gh api --paginate "repos/${repo}/commits/${sha}/statuses?per_page=100" \
    --jq ".[] | select(.context == \"${context}\" and .creator.login == \"${author}\") | .state" | awk 'NR == 1')

  case "${state}" in
  success)
    echo "${context} is success: the update has met the minimum release age."
    exit 0
    ;;
  pending)
    echo "${context} is ${state}: the update hasn't met the minimum release age."
    explain "Waiting for the minimum release age" \
      "Renovate hasn't marked this update as old enough yet (${context} is pending). Nothing is wrong: this check runs again by itself when Renovate sets the status to success, and the update can't be merged until then."
    exit 1
    ;;
  failure | error)
    echo "${context} is ${state}."
    explain "The release age check failed" \
      "${context} is ${state}, so Renovate couldn't confirm the age of this update. Look at the Renovate run's log."
    exit 1
    ;;
  esac

  if [[ ${undated} == true ]]; then
    echo "No ${context} status, as expected for an update with no release date."
    exit 0
  fi

  echo "Waiting for ${author} to set ${context} (${attempt}/${attempts})"
  sleep "${seconds}"
done

echo "${author} never set ${context} on ${sha}."
explain "No release age status" \
  "${author} didn't set ${context} on ${sha} within $((attempts * seconds)) seconds. Run this check again once Renovate has run on the pull request."
exit 1
