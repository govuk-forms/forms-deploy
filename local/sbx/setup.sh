#!/usr/bin/env bash
# One-time setup for the GOV.UK Forms sandbox. Safe to re-run: each step is
# skipped if it's already done. See README.md in this directory.
#
#   ./setup.sh [--github | --no-github]
#
# --github / --no-github answer the "GitHub token" question without prompting.
set -euo pipefail

GATEWAY_HOST=licenseportal.aiengineeringlab.co.uk
SKILLS_REPO=https://gitlab.com/gitlab-org/ai/skills
APPS="forms-admin forms-runner forms-product-page"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WS="$(cd "$SCRIPT_DIR/../../.." && pwd)"

github=ask
for arg in "$@"; do
  case "$arg" in
    --github) github=yes ;;
    --no-github) github=no ;;
    -h | --help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

step() { printf '\n== %s\n' "$*"; }
ok() { echo "   ✓ $*"; }
note() { echo "   - $*"; }

step "Checking prerequisites"
if ! command -v sbx >/dev/null; then
  echo "   sbx isn't installed. See https://docs.docker.com/ai/sandboxes/install/" >&2
  exit 1
fi
ok "sbx $(sbx version 2>/dev/null | awk '{print $3}')"
missing=""
for app in $APPS; do
  [ -d "$WS/$app" ] || missing="$missing $app"
done
if [ -n "$missing" ]; then
  echo "   Clone these next to forms-deploy in $WS first:$missing" >&2
  exit 1
fi
ok "repos found in $WS"

secrets="$(sbx secret ls 2>/dev/null || true)"

step "GitHub token (optional)"
if echo "$secrets" | grep -Eq '^\(global\)[[:space:]]+service[[:space:]]+github[[:space:]]'; then
  ok "already set"
else
  if [ "$github" = ask ]; then
    note "With a token, Claude in the sandbox can push and open PRs."
    note "Without one, it commits locally and you push from your Mac."
    read -r -p "   Let the sandbox push and open PRs with a GitHub token? [y/N] " answer
    case "$answer" in [yY]*) github=yes ;; *) github=no ;; esac
  fi
  if [ "$github" = yes ]; then
    note "Paste a fine-grained PAT with Contents and Pull requests (read and"
    note "write) on the govuk-forms repos."
    sbx secret set github
    ok "stored"
  else
    note "skipped. To add one later: sbx secret set github"
  fi
fi

step "Model gateway key"
if echo "$secrets" | grep -Eq '^\(global\)[[:space:]]+service[[:space:]]+ai-gateway[[:space:]]'; then
  ok "already set"
else
  read -r -s -p "   Paste your LiteLLM key (sk-...): " key
  echo
  # Pasted keys often pick up whitespace or quotes, including curly ones,
  # which the gateway rejects
  key="$(printf '%s' "$key" | tr -d '[:space:]' |
    sed -e "s/[\"']//g" -e 's/“//g' -e 's/”//g' -e "s/‘//g" -e "s/’//g")"
  case "$key" in
    sk-?*) ;;
    *) echo "   That doesn't look like a LiteLLM key: it should start with sk-" >&2; exit 1 ;;
  esac
  # The ai-gateway kit declares this service, and sbxenv.yaml approves it for
  # the gateway host only
  printf '%s' "$key" | sbx secret set ai-gateway >/dev/null
  unset key
  ok "stored as the ai-gateway secret"
fi
# Earlier versions of this script stored the key as a custom secret
if echo "$secrets" | grep -Eq "^\(global\)[[:space:]]+${GATEWAY_HOST}[[:space:]]"; then
  note "The old custom secret for $GATEWAY_HOST is no longer used. Remove it with:"
  note "sbx secret rm --placeholder proxy-managed"
fi

step "Commit message skill"
if sbx skills ls 2>/dev/null | grep -Eq '^commit-messages[[:space:]]'; then
  ok "already installed"
else
  sbx skills add "$SKILLS_REPO" --skill commit-messages >/dev/null
  ok "installed"
fi

step "Git identity for commits in the sandbox"
name="$(git config --global user.name || true)"
email="$(git config --global user.email || true)"
defaults="$HOME/.sbxenv.yaml"
if [ -z "$name" ] || [ -z "$email" ]; then
  note "set git config --global user.name and user.email, then re-run this"
elif [ ! -f "$defaults" ]; then
  cat > "$defaults" <<EOF
# Personal defaults merged into every \`sbx env\` environment.
schemaVersion: "1"

env:
  # Git identity for commits made inside sandboxes
  GIT_AUTHOR_NAME: "$name"
  GIT_AUTHOR_EMAIL: "$email"
  GIT_COMMITTER_NAME: "$name"
  GIT_COMMITTER_EMAIL: "$email"
EOF
  ok "wrote $defaults ($name <$email>)"
elif grep -q 'GIT_AUTHOR_NAME' "$defaults"; then
  ok "already in $defaults"
else
  note "$defaults exists, so it wasn't changed. Add these under env: in it:"
  for var in AUTHOR COMMITTER; do
    echo "     GIT_${var}_NAME: \"$name\""
    echo "     GIT_${var}_EMAIL: \"$email\""
  done
fi

step "Done. Start the sandbox with:"
echo "   cd $SCRIPT_DIR && sbx env run"
