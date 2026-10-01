# GOV.UK Forms in a Docker Sandbox

Use this to work on GOV.UK Forms with Claude Code in a [Docker Sandbox][sbx].
A sandbox is an isolated Linux virtual machine. Claude can only see and change
what's inside it.

The sandbox has:

- forms-admin, forms-runner, forms-product-page and forms-deploy, shared with
  your machine so changes show on both sides straight away
- the Ruby and Node versions each app needs
- Postgres and Valkey
- each app's gems, npm packages and databases, ready to use
- Claude Code, connected to the team's model gateway

The sandbox cannot see any other files on your machine. It also cannot see
your gateway key or GitHub token.

[sbx]: https://docs.docker.com/ai/sandboxes/

## Before you start

You need:

- [Docker Sandboxes][install] installed, and to be signed in with `sbx login`
- the GOV.UK Forms repos cloned side by side, as described in
  [`../README.md`](../README.md)
- your model gateway key, which starts with `sk-`

Your repos should look like this:

```
top-level/
├── forms-admin
├── forms-deploy
├── forms-product-page
└── forms-runner
```

If you want Claude to push and open pull requests, you also need a
[fine-grained GitHub token][pat]. Give it read and write access to
**Contents** and **Pull requests** on the govuk-forms repos. Without a token,
Claude can commit in the sandbox, and you push from your machine as usual.

[install]: https://docs.docker.com/ai/sandboxes/install/
[pat]: https://github.com/settings/personal-access-tokens/new

## Set up the sandbox

You only need to do this once.

1. Run the setup script:

   ```bash
   cd forms-deploy/local/sbx
   ./setup.sh
   ```

2. Choose whether to add a GitHub token.
3. Paste your model gateway key when asked.

The script:

- stores your gateway key and GitHub token as sbx secrets
- installs the [commit messages skill][skill]
- adds your git name and email to `~/.sbxenv.yaml`, so your commits in the
  sandbox are in your name

The sbx proxy adds your secrets to requests as they leave the sandbox, so the
sandbox never sees them.

You can safely run the script again. It skips anything already done. To
answer the GitHub question up front, use `--github` or `--no-github`.

[skill]: https://gitlab.com/gitlab-org/ai/skills/-/blob/main/skills/commit-messages/SKILL.md

## Start the sandbox

From this directory, run:

```bash
sbx env run
```

Always run `sbx env` commands from this directory, without a path. Otherwise
sbx will not use your `~/.sbxenv.yaml`, and your commits will not have your
name and email. sbx also loses track of the sandbox if you mix the two.

The first run takes a few minutes to build and create the sandbox. After that,
it reconnects to the same sandbox and keeps your files, gems and databases.

Each time Claude starts, the sandbox installs anything missing and prepares
the databases in the background. This takes about a minute the first time and
a few seconds after that. Claude knows to wait for it before running specs.

## Run the apps

When you or Claude run an app in the sandbox, open it on your machine:

- forms-admin: http://localhost:3000
- forms-runner: http://localhost:3001
- forms-product-page: http://localhost:3002

## Manage the sandbox

Run these commands from this directory.

| To                           | Run                         |
| ---------------------------- | --------------------------- |
| Run a command in the sandbox | `sbx env exec -- <command>` |
| Stop the sandbox             | `sbx stop govuk-forms`      |
| Delete the sandbox           | `sbx env rm`                |

Deleting the sandbox does not affect your repos.

## Change the sandbox

Changes to `env:` in `sbxenv.yaml` apply the next time you run `sbx env run`.

Changes to kits, bindings or secrets only apply when the sandbox is created.
To pick them up, delete the sandbox with `sbx env rm`, then run `sbx env run`.

## How it works

- [`sbxenv.yaml`](sbxenv.yaml) defines the sandbox: its kits, repos,
  environment variables and ports, and which hosts can receive each secret.
- `~/.sbxenv.yaml` holds your personal settings. sbx merges it with
  `sbxenv.yaml`.
- The agent is Docker's [Claude Code kit][claude-kit]. The 2 [kits][kits] in
  this directory add to it. Each has a descriptor (`<kit>.yaml`), and
  forms-dev also has a Dockerfile for the files it adds.
- [`ai-gateway/`](ai-gateway) connects Claude Code to the model gateway.
  Claude only sees a placeholder in `ANTHROPIC_AUTH_TOKEN`. The sbx proxy
  replaces it with your key on requests to the gateway, and nowhere else.
- [`forms-dev/`](forms-dev) installs build tools and mise, allows the domains
  the setup needs, and declares the optional `github` secret. Each time the
  sandbox starts, it runs:
  - `forms-dev-up`, which starts Postgres and Valkey and gives each app a
    separate `node_modules` in the sandbox. This keeps Linux builds of
    packages like esbuild and rolldown out of your machine's `node_modules`.
  - `forms-app-setup`, which installs everything each app needs.
- forms-dev also gives Claude
  [notes about the sandbox](forms-dev/forms-dev-context.md). The team's
  conventions are in each repo's `AGENTS.md`.
- The sandbox cannot use SSH, so inside the sandbox git rewrites GitHub
  remotes to HTTPS. The proxy adds your GitHub token to those requests.

[claude-kit]: https://hub.docker.com/r/docker/sbx-kit-claude
[kits]: https://docs.docker.com/ai/sandboxes/customize/use-kits/

## Troubleshooting

### Specs fail before they run

The app setup may not have finished, or it may have failed. In the sandbox,
check `/tmp/forms-app-setup.status` and `/tmp/forms-app-setup.log`. To run the
setup again, run `forms-app-setup`.

### Claude gets a 401 error from the gateway

Your gateway key is missing or wrong. Run `sbx secret ls` to check there's a
global `ai-gateway` secret. To replace it, run
`sbx secret rm ai-gateway -f && ./setup.sh`.

### Building a kit fails with "failed to connect to the docker API"

If the `docker` command is installed, sbx uses Docker to build the kits in
this directory. Start Docker Desktop and try again.

### A download or request is blocked

Run `sbx policy log govuk-forms` to see which domains were blocked. Add them
to the network policy's `runtime` list in
[`forms-dev/forms-dev.yaml`](forms-dev/forms-dev.yaml).

### `git push` or `gh` fails in the sandbox

The sandbox needs a GitHub token to push. Push from your machine instead, or
run `sbx secret set github` and then delete and recreate the sandbox.

### Vite fails on your machine after using the sandbox

Linux packages have been written to your machine's `node_modules`. Run
`npm ci` in that app on your machine.

### Claude Code's full screen view will not scroll in tmux

Add `set -g mouse on` to `~/.tmux.conf` to turn on mouse mode, or use the
Page Up and Page Down keys.
