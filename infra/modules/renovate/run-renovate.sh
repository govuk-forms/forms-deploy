#!/usr/bin/env bash
set -euo pipefail

# The token goes straight into the environment, never into the build log.
RENOVATE_TOKEN="$(node /tmp/mint-token.js)"
export RENOVATE_TOKEN

# Renovate runs commands from repository config, such as post-upgrade tasks.
# Once the token exists nothing needs the app's key, so it doesn't stay in the
# environment for them to find.
unset GITHUB_APP_PRIVATE_KEY GITHUB_APP_ID

renovate
