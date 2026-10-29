#!/usr/bin/env bash
# Runs ci-digest.sh over a fixed set of workflow runs and compares the result
# with the digest we worked out by hand. The fixture in testdata/runs.json covers
# a worse-than-usual week, a quiet one, a new and a retired workflow, names that
# Slack would misread, faster and slower run times, and runs that must be ignored
# (cancelled, still running, skipped, and events we do not report on).
#
# Some cases also look up why runs failed, using a stand-in for `gh` that applies
# the script's own --jq filters to canned API responses. They cover timed-out
# jobs, a run whose jobs cannot be read, a spec name that tries to mention the
# whole channel, thousands of failing specs, a limit on the runs explained, and
# the GitHub API failing part way through.

set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0

fail() {
  echo "ci-digest: $1" >&2
  failures=1
}

check() {
  local name=$1 expected_file=$2 actual=$3
  if diff -u "$expected_file" - <<<"$actual"; then
    echo "ci-digest: $name matches $(basename "$expected_file")"
  else
    fail "$name differs from $(basename "$expected_file") (diff above)"
  fi
}

export GH_REPO=example/repo RUNS_FILE="$dir/testdata/runs.json" NOW=1793275200

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
export STUB_DIR="$scratch"

# --- a stand-in for gh ---------------------------------------------------------
cat >"$scratch/gh" <<'STUB'
#!/usr/bin/env bash
filter=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  if [ "${args[$i]}" = "--jq" ]; then filter="${args[$((i + 1))]}"; fi
done

case "$*" in
  "api repos/example/repo --jq .default_branch")
    echo main
    ;;
  *"/actions/runs?"*)
    calls="$STUB_DIR/runs-calls"
    n=$(($(cat "$calls" 2>/dev/null || echo 0) + 1))
    echo "$n" >"$calls"
    if [ "${STUB_FAIL_RUNS_CALL:-0}" = "$n" ]; then
      echo "gh: HTTP 502" >&2
      exit 1
    fi
    echo "$*" >>"${STUB_URLS:-/dev/null}"
    range="$(sed -E 's/.*created=([^&]*)&.*/\1/' <<<"$*")"
    seconds="$(jq -nr --arg a "${range%%..*}" --arg b "${range##*..}" '($b | fromdateiso8601) - ($a | fromdateiso8601)')"
    total=10
    if [ "${STUB_DENSE:-0}" = 1 ]; then total=5000; fi
    if [ "${STUB_SPLIT:-0}" = 1 ] && [ "$seconds" -gt 345600 ]; then total=1500; fi
    echo "{\"total_count\": $total, \"workflow_runs\": []}" | jq -r "$filter"
    ;;
  *"/actions/runs/340/jobs"*)
    echo "gh: HTTP 502" >&2
    exit 1
    ;;
  *"/actions/runs/341/jobs"*)
    echo '{"jobs":[]}' | jq -r "$filter"
    ;;
  *"/jobs"*)
    jq -r "$filter" "$STUB_DIR/jobs.json"
    ;;
  "run view"*"--log-failed"*)
    if [ "${STUB_MANY_SPECS:-0}" = 1 ]; then
      for i in $(seq 1 3000); do
        printf 'job\tstep\t2026-10-29T12:00:00Z rspec ./spec/gen_%04d_spec.rb:1 # fails\n' "$i"
      done
    else
      printf 'job\tstep\t2026-10-29T12:00:00Z rspec ./spec/a_spec.rb:1 # fails\n'
      printf 'job\tstep\t2026-10-29T12:00:00Z rspec ./spec/b<!channel>_spec.rb:2 # fails\n'
    fi
    ;;
  *)
    echo "unexpected gh call: $*" >&2
    exit 1
    ;;
esac
STUB
chmod +x "$scratch/gh"

# What GitHub returns for the jobs of most failed runs: one failed step, the same
# job again (as a matrix of identically named jobs gives), one job that timed out
# without a failed step, one that passed, and one that was cancelled because a
# sibling failed (which should not be reported as a reason). A run counts once
# however many of its jobs failed in the same way.
cat >"$scratch/jobs.json" <<'JSON'
{"jobs": [
  {"name": "build_and_test", "conclusion": "failure",
   "steps": [{"name": "Set up job", "conclusion": "success"}, {"name": "Run Ruby tests", "conclusion": "failure"}]},
  {"name": "build_and_test", "conclusion": "failure",
   "steps": [{"name": "Set up job", "conclusion": "success"}, {"name": "Run Ruby tests", "conclusion": "failure"}]},
  {"name": "slow_job", "conclusion": "timed_out",
   "steps": [{"name": "Set up job", "conclusion": "success"}]},
  {"name": "lint", "conclusion": "success", "steps": []},
  {"name": "sibling", "conclusion": "cancelled",
   "steps": [{"name": "x", "conclusion": "cancelled"}]}
]}
JSON

with_stub() { PATH="$scratch:$PATH" "$@"; }

# --- cases ---------------------------------------------------------------------
check "weekly summary" "$dir/testdata/expected.txt" \
  "$(SKIP_REASONS=1 "$dir/ci-digest.sh")"

check "summary with reasons" "$dir/testdata/expected-with-reasons.txt" \
  "$(with_stub "$dir/ci-digest.sh")"

# With only three runs explained, the newest main failures come first and the
# report says it is a sample.
cat >"$scratch/truncated.txt" <<'EXPECTED'
_Reasons below cover 3 of the 8 failed runs: main and merge queue first, then the newest._

*Why runs failed this week*
• Tests › slow_job › no failed step (timed_out) (1 run)
• Tests › build_and_test › Run Ruby tests (1 run)
• Rare failures › slow_job › no failed step (timed_out) (1 run)
• Rare failures › build_and_test › Run Ruby tests (1 run)
• New workflow › could not read jobs (failure) (1 run)

*Specs failing most often this week*
• `./spec/b&lt;!channel&gt;_spec.rb:2` (3 runs)
• `./spec/a_spec.rb:1` (3 runs)

*Failures on main and in the merge queue*
• Tests (push to main): <https://example.test/runs/1|run>
• New workflow (push to main): <https://example.test/runs/340|run>
• Rare failures (push to main): <https://example.test/runs/350|run>
• Tests (push to main): <https://example.test/runs/2|run>
• Rare failures (push to main): <https://example.test/runs/351|run>
EXPECTED
truncated="$(MAX_RUNS_TO_EXPLAIN=3 with_stub "$dir/ci-digest.sh" | awk '/^_Reasons below/ { p = 1 } p')"
check "reasons limited to a sample" "$scratch/truncated.txt" "$truncated"

# A big breakage can mean thousands of failing specs. Listing only the top five
# must not make the script fail.
cat >"$scratch/many-specs.txt" <<'EXPECTED'
• `./spec/gen_3000_spec.rb:1` (8 runs)
• `./spec/gen_2999_spec.rb:1` (8 runs)
• `./spec/gen_2998_spec.rb:1` (8 runs)
• `./spec/gen_2997_spec.rb:1` (8 runs)
• `./spec/gen_2996_spec.rb:1` (8 runs)
EXPECTED
if many="$(STUB_MANY_SPECS=1 with_stub "$dir/ci-digest.sh")"; then
  check "thousands of failing specs" "$scratch/many-specs.txt" \
    "$(awk '/^\*Specs failing/ { p = 1; next } p && /^$/ { exit } p' <<<"$many")"
else
  fail "the digest failed when thousands of specs failed"
fi

# If GitHub fails part way through reading the runs, report nothing rather than
# a digest built from incomplete data.
if out="$(env -u RUNS_FILE STUB_FAIL_RUNS_CALL=3 PATH="$scratch:$PATH" "$dir/ci-digest.sh" 2>/dev/null)"; then
  fail "the digest succeeded although the GitHub API failed part way through"
elif [ -n "$out" ]; then
  fail "the digest printed a report although the GitHub API failed"
else
  echo "ci-digest: stops without a report when the GitHub API fails"
fi

# GitHub lists at most 1000 runs per query. A week with more than that is read in
# smaller pieces so no run is lost: 13 weeks, each split into two, is 26 reads.
: >"$scratch/urls-split"
if env -u RUNS_FILE STUB_SPLIT=1 STUB_URLS="$scratch/urls-split" PATH="$scratch:$PATH" "$dir/ci-digest.sh" >/dev/null 2>&1; then
  reads="$(grep -c 'per_page=100' "$scratch/urls-split")"
  if [ "$reads" = 26 ]; then
    echo "ci-digest: reads a week with over 1000 runs in two halves"
  else
    fail "expected 26 reads of runs when every week is split in two, got $reads"
  fi
else
  fail "the digest failed when it should have split a week with over 1000 runs"
fi

# If a window is still over the limit once it is too small to split, report
# nothing rather than counts that are too low.
if out="$(env -u RUNS_FILE BASELINE_WEEKS=0 MIN_FETCH_WINDOW=302400 STUB_DENSE=1 PATH="$scratch:$PATH" "$dir/ci-digest.sh" 2>"$scratch/dense.err")"; then
  fail "the digest succeeded although runs were missing from the count"
elif [ -n "$out" ] || ! grep -q 'more than 1000' "$scratch/dense.err"; then
  fail "expected no report and an explanation when a window cannot be split further"
else
  echo "ci-digest: stops without a report when runs would be missing from the count"
fi

# A quiet week: nothing failed, so pull requests collapse to a single line.
run() { # id workflow event branch created
  printf '{"id":%s,"workflow":"%s","event":"%s","branch":"%s","conclusion":"success","created":"%s","started":"%s","ended":"%s","url":"https://example.test/runs/%s"}' \
    "$1" "$2" "$3" "$4" "$5" "$5" "$5" "$1"
}
{
  echo "["
  run 1 Tests push main 2026-10-28T12:00:00Z
  echo ","
  run 2 Tests push main 2026-10-27T12:00:00Z
  echo ","
  run 3 Tests push main 2026-10-10T12:00:00Z
  echo ","
  run 4 Tests push main 2026-09-29T12:00:00Z
  echo ","
  run 5 Lint pull_request feature-x 2026-10-28T12:00:00Z
  echo "]"
} >"$scratch/quiet.json"
cat >"$scratch/quiet.txt" <<'EXPECTED'
*example/repo: CI digest* (22 Oct 2026 to 29 Oct 2026)

*Main and merge queue*
• Tests: 0 of 2 failed (0%); previous 12 weeks: 0 of 2 failed (0%)

*Pull requests*
• No failures in 1 workflow
EXPECTED
check "quiet week" "$scratch/quiet.txt" \
  "$(RUNS_FILE="$scratch/quiet.json" "$dir/ci-digest.sh")"

# No runs at all.
echo "[]" >"$scratch/none.json"
cat >"$scratch/none.txt" <<'EXPECTED'
*example/repo: CI digest* (22 Oct 2026 to 29 Oct 2026)

No completed runs in the last week.
EXPECTED
check "week with no runs" "$scratch/none.txt" \
  "$(RUNS_FILE="$scratch/none.json" "$dir/ci-digest.sh")"

exit "$failures"
