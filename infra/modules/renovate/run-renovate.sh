#!/usr/bin/env bash
set -euo pipefail

# The token goes straight into the environment, never into the build log.
RENOVATE_TOKEN="$(node /tmp/mint-token.js)"
export RENOVATE_TOKEN

renovate
