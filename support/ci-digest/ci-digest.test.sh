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
# the GitHub API failing part way through, and runs that were re-run.

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
export STUB_RUNS="$RUNS_FILE"

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
export STUB_DIR="$scratch"

# --- a stand-in for gh ---------------------------------------------------------
cat >"$scratch/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"${STUB_CALLS:-/dev/null}"
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
  *"/actions/runs/340/"*"jobs"*)
    echo "gh: HTTP 502" >&2
    exit 1
    ;;
  *"/actions/runs/341/"*"jobs"*)
    echo '{"jobs":[]}' | jq -r "$filter"
    ;;
  *"/jobs"*)
    jq -r "$filter" "$STUB_DIR/jobs.json"
    ;;
  *"/actions/runs/"*"/attempts/"*)
    # An earlier attempt of a run, as the real API gives it: the run's created_at, the
    # attempt's own start time (first_started, when the fixture has one), and the
    # plain run URL. Always a failure: that is why it was re-run.
    if [ "${STUB_FAIL_ATTEMPT:-0}" = 1 ]; then
      echo "gh: HTTP 502" >&2
      exit 1
    fi
    id="$(sed -E 's#.*/runs/([0-9]+)/attempts/([0-9]+).*#\1#' <<<"$2")"
    attempt="$(sed -E 's#.*/runs/([0-9]+)/attempts/([0-9]+).*#\2#' <<<"$2")"
    jq -c --argjson id "$id" --argjson attempt "$attempt" '.[] | select(.id == $id) | {id, name: .workflow, event, head_branch: .branch, conclusion: "failure", created_at: .created, run_started_at: (.first_started // .started), updated_at: .ended, html_url: .url, run_attempt: $attempt}' "$STUB_RUNS" | jq -c "$filter"
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
# report says it is a sample. Every failure link names its attempt, so it keeps
# opening that attempt even if the run is re-run later.
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
• Tests (push to main): <https://example.test/runs/1/attempts/1|run>
• New workflow (push to main): <https://example.test/runs/340/attempts/1|run>
• Rare failures (push to main): <https://example.test/runs/350/attempts/1|run>
• Tests (push to main): <https://example.test/runs/2/attempts/1|run>
• Rare failures (push to main): <https://example.test/runs/351/attempts/1|run>
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

# Runs that failed and then passed when they were re-run. GitHub lists a run once,
# as its last attempt, so the failures would vanish. Every attempt counts, placed in
# the week it started (a retry keeps the run's created_at). Run 1 passed on its
# second attempt and run 2 on its third, so this week there are 2 + 3 + 1 + 1 = 7
# attempts of which 1 + 2 = 3 failed. Run 7 was created the week before and failed
# twice: its first attempt is before the cutoff and its re-run is this week, which
# makes 8 attempts with 4 failures this week. Before that, run 5 passed on its
# second attempt, run 6 first time, and run 7's first attempt failed: 2 failures in
# 4 attempts.
rerun() { # id attempts created
  printf '{"id":%s,"workflow":"Flaky","event":"push","branch":"main","conclusion":"success","created":"%s","started":"%s","ended":"%s","url":"https://example.test/runs/%s","run_attempt":%s}' \
    "$1" "$3" "$3" "$3" "$1" "$2"
}
{
  echo "["
  rerun 1 2 2026-10-28T10:00:00Z
  echo ","
  rerun 2 3 2026-10-27T10:00:00Z
  echo ","
  rerun 3 1 2026-10-26T10:00:00Z
  echo ","
  rerun 4 1 2026-10-25T10:00:00Z
  echo ","
  rerun 5 2 2026-10-10T10:00:00Z
  echo ","
  rerun 6 1 2026-10-09T10:00:00Z
  echo ","
  # Created before the cutoff (22 Oct 12:00) and first started then. Its re-run started on the
  # 28th, after run 1, so by start time it is the newest failure and by creation time the oldest.
  # A scheduled run that was re-run. The digest does not report on schedules, so its first attempt is not read.
  printf '{"id":8,"workflow":"Deploy","event":"schedule","branch":"main","conclusion":"success","created":"2026-10-27T09:00:00Z","started":"2026-10-27T09:30:00Z","ended":"2026-10-27T09:35:00Z","url":"https://example.test/runs/8","run_attempt":2},'
  printf '{"id":7,"workflow":"Flaky","event":"push","branch":"main","conclusion":"failure","created":"2026-10-21T10:00:00Z","first_started":"2026-10-21T10:00:00Z","started":"2026-10-28T11:00:00Z","ended":"2026-10-28T11:05:00Z","url":"https://example.test/runs/7","run_attempt":2}'
  echo "]"
} >"$scratch/rerun.json"
cat >"$scratch/rerun.txt" <<'EXPECTED'
*example/repo: CI digest* (22 Oct 2026 to 29 Oct 2026)

*Main and merge queue*
• Flaky: 4 of 8 failed (50%); previous 12 weeks: 2 of 4 failed (50%)

*Why runs failed this week*
• Flaky › slow_job › no failed step (timed_out) (4 runs)
• Flaky › build_and_test › Run Ruby tests (4 runs)

*Specs failing most often this week*
• `./spec/b&lt;!channel&gt;_spec.rb:2` (4 runs)
• `./spec/a_spec.rb:1` (4 runs)

*Failures on main and in the merge queue*
• Flaky (push to main): <https://example.test/runs/7/attempts/2|run>
• Flaky (push to main): <https://example.test/runs/1/attempts/1|run>
• Flaky (push to main): <https://example.test/runs/2/attempts/1|run>
• Flaky (push to main): <https://example.test/runs/2/attempts/2|run>
EXPECTED
: >"$scratch/rerun-calls"
rerun_out="$(RUNS_FILE="$scratch/rerun.json" STUB_RUNS="$scratch/rerun.json" STUB_CALLS="$scratch/rerun-calls" with_stub "$dir/ci-digest.sh")"
check "runs that passed on a re-run" "$scratch/rerun.txt" "$rerun_out"

# Only what is needed is read: the earlier attempts of re-run runs the digest reports
# on (five of them, the latest attempt is already known; the re-run scheduled run 8
# is left out), and the jobs and logs of the four failed attempts, each for its own
# attempt.
runs_read="$(grep -cE 'actions/runs/[0-9]+/attempts/[0-9]+ --jq' "$scratch/rerun-calls" || true)"
jobs_read="$(grep -cE 'actions/runs/[0-9]+/attempts/[0-9]+/jobs' "$scratch/rerun-calls" || true)"
logs_read="$(grep -cE '^run view [0-9]+ --attempt [0-9]+ --log-failed' "$scratch/rerun-calls" || true)"
if [ "$runs_read" = 5 ] && [ "$jobs_read" = 4 ] && [ "$logs_read" = 4 ]; then
  echo "ci-digest: reads only the attempts it needs (5 earlier attempts, 4 sets of jobs, 4 logs)"
else
  fail "expected 5 earlier attempts, 4 sets of jobs and 4 logs to be read, got $runs_read, $jobs_read and $logs_read"
fi

# If an earlier attempt cannot be read, report nothing rather than counts that
# leave a failure out.
if out="$(RUNS_FILE="$scratch/rerun.json" STUB_RUNS="$scratch/rerun.json" STUB_FAIL_ATTEMPT=1 with_stub "$dir/ci-digest.sh" 2>/dev/null)"; then
  fail "the digest succeeded although an earlier attempt could not be read"
elif [ -n "$out" ]; then
  fail "the digest printed a report although an earlier attempt could not be read"
else
  echo "ci-digest: stops without a report when an earlier attempt cannot be read"
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

# GitHub allows a run to have no name, and so does each of its attempts. That must
# not take the digest down, including for a run that was re-run: run 3 failed and
# then passed, so this week there are 1 + 1 + 1 = 3 attempts with 1 failure, and
# the week before has run 2 only.
cat >"$scratch/noname.json" <<'JSON'
[
 {"id":1,"workflow":null,"event":"push","branch":"main","conclusion":"success","created":"2026-10-28T12:00:00Z","started":"2026-10-28T12:00:00Z","ended":"2026-10-28T12:01:00Z","url":"https://example.test/runs/1"},
 {"id":2,"workflow":null,"event":"push","branch":"main","conclusion":"success","created":"2026-10-10T12:00:00Z","started":"2026-10-10T12:00:00Z","ended":"2026-10-10T12:01:00Z","url":"https://example.test/runs/2"},
 {"id":3,"workflow":null,"event":"push","branch":"main","conclusion":"success","created":"2026-10-27T12:00:00Z","started":"2026-10-27T12:30:00Z","ended":"2026-10-27T12:31:00Z","url":"https://example.test/runs/3","run_attempt":2}
]
JSON
cat >"$scratch/noname.txt" <<'EXPECTED'
*example/repo: CI digest* (22 Oct 2026 to 29 Oct 2026)

*Main and merge queue*
• (unnamed workflow): 1 of 3 failed (33%); previous 12 weeks: 0 of 1 failed (0%)
EXPECTED
check "runs with no workflow name" "$scratch/noname.txt" \
  "$(RUNS_FILE="$scratch/noname.json" STUB_RUNS="$scratch/noname.json" SKIP_REASONS=1 with_stub "$dir/ci-digest.sh")"

# No runs at all.
echo "[]" >"$scratch/none.json"
cat >"$scratch/none.txt" <<'EXPECTED'
*example/repo: CI digest* (22 Oct 2026 to 29 Oct 2026)

No completed runs in the last week.
EXPECTED
check "week with no runs" "$scratch/none.txt" \
  "$(RUNS_FILE="$scratch/none.json" "$dir/ci-digest.sh")"

exit "$failures"
