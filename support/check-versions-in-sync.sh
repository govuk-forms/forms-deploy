#!/usr/bin/env bash
#
# Fails if two pins of the same tool disagree. Some tools are pinned in more
# than one place because the places can't share a config (for example
# pre-commit has to work for people without mise).
#
# .github/workflows/guardrail_versions_in_sync.yml says what to compare.
#
# Usage: check-versions-in-sync.sh NAME LOCATION VERSION LOCATION VERSION...
#
# Takes two or more LOCATION VERSION pairs and fails unless every version is
# the same.

set -euo pipefail

if [ "$#" -lt 5 ] || [ $((($# - 1) % 2)) -ne 0 ]; then
  echo "Usage: $0 NAME LOCATION VERSION LOCATION VERSION..." >&2
  exit 2
fi

name="$1"
shift

locations=()
versions=()
while [ "$#" -gt 0 ]; do
  locations+=("$1")
  versions+=("$2")
  shift 2
done

missing=false
differ=false
for version in "${versions[@]}"; do
  if [ -z "${version}" ]; then
    missing=true
  elif [ "${version}" != "${versions[0]}" ]; then
    differ=true
  fi
done

if [ "${missing}" = true ]; then
  title="${name} version not found"
  heading="Could not find the ${name} version in every place"
elif [ "${differ}" = true ]; then
  title="${name} versions differ"
  heading="${name} versions differ. Set them to the same version:"
else
  exit 0
fi

details=""
for i in "${!locations[@]}"; do
  details+="${locations[$i]}: '${versions[$i]}'"$'\n'
done
details="${details%$'\n'}"

echo "${heading}"
echo "${details}"

# Without this the only annotation is "Process completed with exit code 1."
if [ "${GITHUB_ACTIONS:-}" = true ]; then
  message="${details//'%'/%25}"
  message="${message//$'\r'/%0D}"
  message="${message//$'\n'/%0A}"
  echo "::error title=${title}::${message}"
fi
exit 1
