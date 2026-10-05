# GOV.UK Forms sandbox

You are in a Docker sandbox, in the folder holding the GOV.UK Forms repos
(forms-admin, forms-runner, forms-product-page, forms-deploy), mounted from
the host at its host path. Each repo is its own git repository, so run git
from inside the repo you are changing.

## Commits and pull requests

The rules are in `forms-deploy/AGENTS.md` and apply in every repo here, not
only forms-deploy. Read that file and follow it before you commit, push, or
open or update a pull request.

## Sandbox

- Ruby and Node come from mise, at the versions in each app's `.ruby-version`
  and `.nvmrc`, and are already on PATH.
- Postgres (postgres/postgres) and Valkey run on localhost:5432 and :6379 via
  Docker Compose.
- On each start, `forms-app-setup` runs in the background. It installs Ruby,
  Node, gems and npm packages and creates the development and test databases
  for each app. Check `/tmp/forms-app-setup.status` (`running`, `done` or
  `failed: <apps>`) and `/tmp/forms-app-setup.log` before running specs. No
  status file means the setup hasn't started. Re-run it with
  `forms-app-setup`, which exits straight away if a run is still going.
- Chrome for Testing and its chromedriver are installed for the feature and
  integration specs, which run headless as they do in CI. There is no
  display, so don't set `SETTINGS__SHOW_BROWSER_DURING_TESTS`.
- Each app's `node_modules` is a sandbox-only Linux copy mounted over the
  host's macOS one. `npm ci` and `npm install` are safe here and don't affect
  the host. Don't unmount it.
- Don't export RAILS_ENV, REDIS_URL or SETTINGS__* globally. They leak into
  specs: `spec/rails_helper.rb` only picks `test` when RAILS_ENV is unset, and
  the others override the apps' test settings.
- Rails apps listen on 0.0.0.0 (BINDING) on ports 3000 (admin), 3001 (runner)
  and 3002 (product page). The host reaches them on 3100, 3101 and 3102, so
  give the user those ports when you tell them where to open an app.
- GitHub remotes are rewritten to HTTPS in this sandbox, and the proxy
  supplies the user's GitHub token if they set one. Check with
  `gh auth status`. If there's no token, `git push` and `gh pr create` won't
  work: commit locally and tell the user to push from the host. Don't change
  the repos' remote URLs.
