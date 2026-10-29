#!/usr/bin/env bash
# Summarises how often a repository's GitHub Actions workflows fail, and how long
# they take, over the last week compared with the weeks before it. Prints a
# Slack message (mrkdwn) on stdout. See README.md.
#
# Usage: GH_REPO=govuk-forms/forms-admin support/ci-digest/ci-digest.sh
#
# Environment:
#   GH_REPO          owner/name of the repository to report on (required)
#   GH_TOKEN         token for `gh` with `actions: read` (not needed if you are logged in)
#   BASELINE_WEEKS   weeks before the last one to compare with (default 12)
#   DEFAULT_BRANCH   branch whose pushes count as "main" (default: the repository's default branch)
#   INCLUDE_SPECS    set to 0 to skip downloading failed logs to name failing specs
#   SKIP_REASONS     set to 1 to skip looking up why runs failed (used by the tests)
#   MAX_RUNS_TO_EXPLAIN  how many failed runs to look up reasons for (default 40)
#   MIN_FETCH_WINDOW seconds below which a busy range is no longer split (default 3600; used by the tests)
#   RUNS_FILE, NOW   for the tests: read runs from this file, and treat NOW (epoch seconds) as the time

set -euo pipefail

: "${GH_REPO:?Set GH_REPO to owner/name}"
weeks="${BASELINE_WEEKS:-12}"
now="${NOW:-$(date -u +%s)}"
include_specs="${INCLUDE_SPECS:-1}"
skip_reasons="${SKIP_REASONS:-0}"
max_explained="${MAX_RUNS_TO_EXPLAIN:-40}"
min_window="${MIN_FETCH_WINDOW:-3600}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

iso() { jq -nr --argjson t "$1" '$t | strftime("%Y-%m-%dT%H:%M:%SZ")'; }

# Appends to $3 the runs created between epochs $1 and $2. GitHub lists at most
# 1000 runs for a query, so when it says there are more than that the range is
# cut in half and each half read separately. If a range is already too small to
# cut and still has more, stop: the counts would be too low to report.
#
# Bash switches errexit off inside a command substitution, and this runs in one,
# so every command that can fail needs its own check. Otherwise a failed request
# would leave a gap and we would report a digest built on partial data.
fetch_window() {
  local from=$1 to=$2 out=$3 start end total mid
  start="$(iso "$from")" || return 1
  end="$(iso "$to")" || return 1
  total="$(gh api "repos/${GH_REPO}/actions/runs?created=${start}..${end}&per_page=1" --jq .total_count)" || return 1
  if [ "$total" -gt 1000 ]; then
    if [ $((to - from)) -le "$min_window" ]; then
      echo "ci-digest: more than 1000 runs between ${start} and ${end}, which cannot be read in smaller pieces" >&2
      return 1
    fi
    mid=$(((from + to) / 2))
    fetch_window "$from" "$mid" "$out" || return 1
    fetch_window "$mid" "$to" "$out" || return 1
    return 0
  fi
  gh api --paginate "repos/${GH_REPO}/actions/runs?created=${start}..${end}&per_page=100" \
    --jq '.workflow_runs[] | {id, workflow: .name, event, branch: .head_branch, conclusion, created: .created_at, started: .run_started_at, ended: .updated_at, url: .html_url}' \
    >>"$out" || return 1
}

# One week at a time, the most recent week being week 0. The ends of two ranges
# share a second, so a run can be read twice; unique_by drops the repeats.
fetch_runs() {
  local k
  for ((k = 0; k <= weeks; k++)); do
    : >"$tmp/week-$k.jsonl"
    fetch_window $((now - (k + 1) * 604800)) $((now - k * 604800)) "$tmp/week-$k.jsonl" || return 1
  done
  jq -s 'unique_by(.id)' "$tmp"/week-*.jsonl
}

esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

# Counts identical lines and prints the commonest, e.g. "• Tests › build › Run Ruby tests (5 runs)".
# awk reads all its input and prints the first five lines. `head` would close the
# pipe early, which kills `sort` with SIGPIPE and, with pipefail, fails the script.
top() {
  LC_ALL=C sort | uniq -c | LC_ALL=C sort -rn |
    awk 'NR <= 5 { n = $1; $1 = ""; sub(/^ /, ""); printf "• %s (%d run%s)\n", $0, n, (n == 1 ? "" : "s") }'
}

# For each failed run, record which job and step failed and, where the logs are
# still available, which specs failed. Runs are taken in the order they arrive:
# main and the merge queue first, then the newest.
collect_reasons() {
  local failed_json=$1 id workflow conclusion job step
  : >"$tmp/reasons.txt"
  : >"$tmp/specs.txt"
  jq -r --argjson max "$max_explained" '.[:$max][] | [.id, .workflow, .conclusion] | @tsv' <<<"$failed_json" |
    while IFS=$'\t' read -r id workflow conclusion; do
      # shellcheck disable=SC2016 # $c is a jq variable, not a shell one
      if gh api --paginate "repos/${GH_REPO}/actions/runs/${id}/jobs?per_page=100" \
        --jq '.jobs[] | select(.conclusion == "failure" or .conclusion == "timed_out" or .conclusion == "startup_failure") | .conclusion as $c | [.name, ([.steps[]? | select(.conclusion == "failure") | .name] | first // "no failed step (\($c))")] | @tsv' \
        >"$tmp/jobs.tsv" 2>/dev/null; then
        if [ -s "$tmp/jobs.tsv" ]; then
          # Once per run: a matrix can fail the same way in many identically named
          # jobs, and we count runs.
          while IFS=$'\t' read -r job step; do
            printf '%s › %s › %s\n' "$workflow" "$job" "$step" >>"$tmp/reasons.txt"
          done < <(LC_ALL=C sort -u "$tmp/jobs.tsv")
        else
          # For example a workflow that failed to start has no jobs at all.
          printf '%s › no failed job found (%s)\n' "$workflow" "$conclusion" >>"$tmp/reasons.txt"
        fi
      else
        printf '%s › could not read jobs (%s)\n' "$workflow" "$conclusion" >>"$tmp/reasons.txt"
      fi
      if [ "$include_specs" = 1 ]; then
        # Once per run, so a spec that fails twice in one run still counts once.
        { gh run view "$id" --log-failed 2>/dev/null || true; } |
          { grep -oE 'rspec \./spec/[^ ]+' || true; } | sort -u | sed 's/^rspec //' >>"$tmp/specs.txt"
      fi
    done
}

if [ -n "${RUNS_FILE:-}" ]; then
  branch="${DEFAULT_BRANCH:-main}"
  runs="$(cat "$RUNS_FILE")"
else
  branch="${DEFAULT_BRANCH:-}"
  if [ -z "$branch" ]; then
    branch="$(gh api "repos/${GH_REPO}" --jq .default_branch)"
  fi
  runs="$(fetch_runs)" || {
    echo "ci-digest: could not read the workflow runs from GitHub, so there is no digest" >&2
    exit 1
  }
fi

result="$(jq --argjson now "$now" --argjson weeks "$weeks" --arg branch "$branch" --arg repo "$GH_REPO" \
  -f "$script_dir/ci-digest.jq" <<<"$runs")"
failed="$(jq -c .failed <<<"$result")"

jq -r .report <<<"$result"

failed_count="$(jq length <<<"$failed")"

if [ "$failed_count" -gt 0 ] && [ "$skip_reasons" != 1 ]; then
  collect_reasons "$failed"

  if [ "$failed_count" -gt "$max_explained" ]; then
    printf '\n_Reasons below cover %d of the %d failed runs: main and merge queue first, then the newest._\n' \
      "$max_explained" "$failed_count"
  fi

  if [ -s "$tmp/reasons.txt" ]; then
    printf '\n*Why runs failed this week*\n'
    esc <"$tmp/reasons.txt" | top
  fi
  if [ -s "$tmp/specs.txt" ]; then
    printf '\n*Specs failing most often this week*\n'
    # Spec names come from the logs of runs that may be from pull requests, so
    # escape them: Slack would otherwise turn <!channel> into a mention.
    esc <"$tmp/specs.txt" | sed -e 's/^/`/' -e 's/$/`/' | top
  fi

  if [ "$(jq '[.[] | select(.kind == "main")] | length' <<<"$failed")" -gt 0 ]; then
    printf '\n*Failures on main and in the merge queue*\n'
    jq -r '[.[] | select(.kind == "main")][:5][] | "• \(.workflow | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;")) (\(if .event == "merge_group" then "merge queue" else "push to main" end)): <\(.url)|run>"' <<<"$failed"
  fi
fi
