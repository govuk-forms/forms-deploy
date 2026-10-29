# Builds the weekly CI digest from a JSON array of workflow runs.
#
# Arguments: $now (epoch seconds), $weeks (how many weeks the baseline covers),
# $branch (the default branch) and $repo (owner/name, used in the heading).
#
# Output: {report: <Slack mrkdwn text>, failed: [<runs that failed this week>]}

def failed: .conclusion == "failure" or .conclusion == "timed_out" or .conclusion == "startup_failure";
def counted: .conclusion == "success" or failed;
def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
# Nearest-rank, which suits the p95: a slow run really did take that long.
def percentile($p): if length == 0 then null else sort | .[(($p * length) | ceil) - 1] end;
# The usual median: with an even number of values, the average of the middle two.
def median:
  if length == 0 then null
  else sort | (length / 2 | floor) as $i
    | if length % 2 == 1 then .[$i] else (.[$i - 1] + .[$i]) / 2 end
  end;
def duration:
  if . == null then "n/a"
  else floor as $s | if $s >= 60 then "\(($s / 60) | floor)m\($s % 60)s" else "\($s)s" end
  end;
def tenths: (. * 10 | round) / 10;
def share($part; $whole): if $whole == 0 then "0%" else "\(($part * 100 / $whole) | round)%" end;
def day: strftime("%d %b %Y");

# "main" is anything that has already been through review: the merge queue and
# pushes to the default branch. A failure there is either a flaky test or a real
# regression, which is what we most want to hear about. Pull request runs are
# reported separately, because developers fail those on purpose all the time.
def kind:
  if .event == "merge_group" or (.event == "push" and .branch == $branch) then "main"
  elif .event == "pull_request" then "pr"
  else null end;

($now - 604800) as $cut
| [ .[]
    | select(counted)
    | . + { kind: kind }
    | select(.kind != null)
    | . + { created_at: (.created | fromdateiso8601),
            secs: ((.ended | fromdateiso8601) - ((.started // .created) | fromdateiso8601)) }
    | . + { recent: (.created_at >= $cut) } ] as $runs

| def rows($k):
    [ $runs[] | select(.kind == $k) ]
    | group_by(.workflow)
    | map(
        (map(select(.recent))) as $r
        | (map(select(.recent | not))) as $b
        | { name: (.[0].workflow | esc),
            rn: ($r | length), rf: ($r | map(select(failed)) | length),
            bn: ($b | length), bf: ($b | map(select(failed)) | length) }
        # Flag a workflow as worse than usual when it failed at least three times
        # and its failure rate is more than double the baseline. Fewer failures
        # than that is too small a sample to mean anything.
        | . + { worse: (.rn > 0 and .rf >= 3 and .bn > 0 and (.rf / .rn) > 2 * (.bf / .bn)) });

  def line:
    "• \(.name): "
    + (if .rn == 0 then "no runs this week" else "\(.rf) of \(.rn) failed (\(share(.rf; .rn)))" end)
    + (if .bn == 0 then "; no earlier runs to compare with"
       else "; previous \($weeks) weeks: \(.bf) of \(.bn) failed (\(share(.bf; .bn)))" end)
    + (if .worse then " :warning:" else "" end);

  # Pull request runs fail all the time while people work, so only list the
  # workflows that failed this week and count the rest. Main and the merge queue
  # list everything: a row of zeros there is how we know it was a quiet week.
  def section($title; $k):
    rows($k) as $all
    | (if $k == "pr" then ($all | map(select(.rf > 0))) else $all end) as $shown
    | ($all | length - ($shown | length)) as $quiet
    | if ($all | length) == 0 then empty
      else "*\($title)*\n"
        + ([ ($shown | map(line)[]),
             (if $quiet == 0 then empty
              elif ($shown | length) == 0 then "• No failures in \($quiet) workflow\(if $quiet == 1 then "" else "s" end)"
              else "• \($quiet) other workflow\(if $quiet == 1 then "" else "s" end) had no failures" end)
           ] | join("\n"))
      end;

  # Compare how long successful runs take. Failed runs are left out because they
  # often stop early, which would make a bad week look fast.
  def timings:
    [ $runs[] | select(.conclusion == "success") ]
    | group_by(.workflow)
    | map(
        (map(select(.recent) | .secs)) as $r
        | (map(select(.recent | not) | .secs)) as $b
        | select(($r | length) >= 5 and ($b | length) >= 10)
        | ($r | median) as $rm
        | ($b | median) as $bm
        | "• \(.[0].workflow | esc): median \($rm | duration) (usual \($bm | duration))"
          + (if ($r | length) >= 20 and ($b | length) >= 20
             then ", p95 \($r | percentile(0.95) | duration) (usual \($b | percentile(0.95) | duration))"
             else "" end)
          + (if $rm >= $bm * 1.25 and ($rm - $bm) >= 30 then " :warning: slower"
             elif $rm <= $bm * 0.75 and ($bm - $rm) >= 30 then " :zap: faster"
             else "" end));

  {
    report: (
      [ "*\($repo): CI digest* (\($cut | day) to \($now | day))",
        (if ([ $runs[] | select(.recent) ] | length) == 0 then "No completed runs in the last week." else empty end),
        section("Main and merge queue"; "main"),
        section("Pull requests"; "pr"),
        (timings as $t | if ($t | length) == 0 then empty else "*Run times* (successful runs)\n" + ($t | join("\n")) end)
      ] | join("\n\n")),
    # Main and the merge queue first, then the newest, so that a limit on how many
    # runs we look into keeps the failures that matter most.
    failed: ([ $runs[] | select(.recent and failed) ]
             | sort_by([.kind != "main", -.created_at, .id, .run_attempt])
             | map({id, run_attempt, workflow, kind, event, branch, url, conclusion}))
  }
