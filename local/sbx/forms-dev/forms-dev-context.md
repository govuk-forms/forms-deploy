# GOV.UK Forms sandbox

You are in a Docker sandbox with the GOV.UK Forms repos mounted from the host
at their host paths. Each repo's AGENTS.md has the team's conventions; these
notes only cover the sandbox.

- Ruby and Node come from mise, at the versions in each app's `.ruby-version`
  and `.nvmrc`, and are already on PATH.
- Postgres (postgres/postgres) and Valkey run on localhost:5432 and :6379 via
  Docker Compose.
- On each start, `forms-app-setup` runs in the background. It installs Ruby,
  Node, gems and npm packages and creates the development and test databases
  for each app. Check `/tmp/forms-app-setup.status` (`running`, `done` or
  `failed: <apps>`) and `/tmp/forms-app-setup.log` before running specs.
  Re-run it with `forms-app-setup`.
- Each app's `node_modules` is a sandbox-only Linux copy mounted over the
  host's macOS one. `npm ci` and `npm install` are safe here and don't affect
  the host. Don't unmount it.
- Don't export RAILS_ENV, REDIS_URL or SETTINGS__* globally. They leak into
  specs: `spec/rails_helper.rb` only picks `test` when RAILS_ENV is unset, and
  the others override the apps' test settings.
- Rails apps listen on 0.0.0.0 (BINDING), and ports 3000 (admin), 3001
  (runner) and 3002 (product page) are published to the host.
- GitHub remotes are rewritten to HTTPS in this sandbox, and the proxy
  supplies the user's GitHub token if they set one. Check with
  `gh auth status`. If there's no token, `git push` and `gh pr create` won't
  work: commit locally and tell the user to push from the host. Don't change
  the repos' remote URLs.
