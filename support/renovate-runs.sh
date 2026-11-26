#!/usr/bin/env bash
#
# Controls the Renovate runner in whichever AWS account the credentials are for,
# so run it through `gds aws`:
#
#   gds aws forms-dev-admin -- support/renovate-runs.sh suspend
#
# Usage: renovate-runs.sh COMMAND [ARGS]
#
#   status                     Whether it is suspended, and each repo's run
#   suspend                    Stop anything starting. Requests are kept
#   resume                     Start again, with whatever was kept
#   run [REPO|all] [full|event]  Ask for a run. Defaults to all, full

set -euo pipefail

region=eu-west-2
function_name=renovate-orchestrator
table=renovate-runs

export AWS_PAGER=""

invoke() {
  local out result
  out="$(mktemp)"
  result="$(aws lambda invoke --region "${region}" --function-name "${function_name}" \
    --cli-binary-format raw-in-base64-out --payload "$1" \
    --log-type Tail --output json "${out}")"

  # The orchestrator logs what it decided, which is the answer.
  jq -r .LogResult <<<"${result}" | base64 --decode | sed -n 's/^.*INFO\t//p;s/^.*ERROR\t//p'

  # The invocation can succeed while the function fails, which only shows here.
  if [[ -n "$(jq -r '.FunctionError // empty' <<<"${result}")" ]]; then
    echo "The orchestrator failed: $(cat "${out}")" >&2
    rm -f "${out}"
    return 1
  fi
  rm -f "${out}"
}

status() {
  aws dynamodb scan --region "${region}" --table-name "${table}" --output json |
    jq -r '
      .Items
      | (map(select(.repo.S == "_control"))[0].suspended.BOOL // false) as $suspended
      | "suspended: \($suspended)",
        (.[] | select(.repo.S != "_control")
         | "\(.repo.S)  pending: \(.pending.S // "-")  build: \(.buildId.S // "-")")'
}

command="${1:-}"
case "${command}" in
  status) status ;;
  suspend) invoke '{"action":"suspend"}' ;;
  resume) invoke '{"action":"resume"}' ;;
  run)
    repos="${2:-all}"
    mode="${3:-full}"
    if [[ ${mode} != "full" && ${mode} != "event" ]]; then
      echo "The run type is full or event, not ${mode}" >&2
      exit 1
    fi
    if [[ ${repos} == "all" ]]; then
      invoke "$(jq -nc --arg mode "${mode}" '{action: "request", repos: "all", mode: $mode}')"
    else
      invoke "$(jq -nc --arg repo "${repos}" --arg mode "${mode}" '{action: "request", repos: [$repo], mode: $mode}')"
    fi
    ;;
  *)
    sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 1
    ;;
esac
