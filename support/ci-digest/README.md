# CI digest

A weekly Slack summary of how a repository's GitHub Actions workflows are doing:
how often they fail, why, and how long they take, this week compared with the 12
weeks before it. It uses the GitHub API only, so it keeps no state of its own.

Each forms repo runs it on a schedule through
`.github/workflows/reusable-ci-digest.yml`. The workflow checks this directory out
from `main`, runs `ci-digest.sh` and writes the result to the job summary.

## Dry run, and going live

It is a dry run for now: nothing is posted to Slack, so read the digests in the
job summary of each repo's "CI digest" runs. Once they look useful, change the
default of `dry_run` to `false` in `reusable-ci-digest.yml`. Every repo then posts
on its next run, with no change needed in the repos themselves. The webhook is the
org secret `SLACK_WEBHOOK_GOVUK_FORMS_DEPLOYMENTS`, which must be available to
each repo by then.

## Reading a digest

- **Main and merge queue** covers runs that happen after review: the merge queue
  and pushes to the default branch. A failure here is a flaky test or a real
  regression, so this is the section to watch.
- **Pull requests** is reported separately because developers fail those runs all
  the time while they work. Only workflows that failed this week are listed, and
  the rest are counted on one line.
- Each row compares this week with the totals for the previous 12 weeks.
  `:warning:` means a workflow failed at least three times this week and its
  failure rate is more than double the previous rate. Change the rule in
  `ci-digest.jq`.
- **Run times** compare successful runs only, because failed runs often stop
  early. `slower` and `faster` mean the median moved by at least 25% and 30
  seconds. The p95 is shown once there are 20 runs in both periods.
- **Why runs failed** names the job and step that failed, including jobs that
  timed out. **Specs failing most often** comes from the failed logs, so it only
  covers runs whose logs have not expired, and only for RSpec output. Both look
  into at most 40 failed runs, taking main and the merge queue first and then the
  newest, and say so when they have to leave some out.
- Only a run's final attempt is seen. A run that failed and then passed when
  its failed jobs were re-run counts as a success, so a failure hidden that way
  is not in the digest yet.
- GitHub lists at most 1000 runs for a query, so a week with more than that is
  read in smaller pieces. If GitHub cannot be read part way through, or a piece
  is still over the limit when it is an hour long, the script exits with an error
  and prints no digest, rather than reporting numbers built on missing runs.

Only runs that finished as success, failure, timed out or failed to start are
counted. Cancelled, skipped and in-progress runs are ignored.

## Running it locally

You need `gh` (logged in, or with `GH_TOKEN` set) and `jq`.

    GH_REPO=govuk-forms/forms-admin support/ci-digest/ci-digest.sh

It takes a few minutes for a busy repo, because it reads 13 weeks of runs. See the
top of `ci-digest.sh` for the options.

## Tests

    support/ci-digest/ci-digest.test.sh

This runs the script over `testdata/runs.json` and compares the result with
`testdata/expected.txt`, which was worked out by hand. If you change how the
digest is worked out, change the fixture to cover the new behaviour as well.

## Trying the workflow

In forms-deploy, a pull request that changes the digest runs it on the pull
request, using that pull request's own script, and shows the result in the job
summary. Only scheduled and manually started runs can post to Slack, so runs
from any other trigger are always a dry run.

In the other repos the schedule only runs from the default branch, so after
merging, run "CI digest" from the Actions tab to see the digest straight away.
