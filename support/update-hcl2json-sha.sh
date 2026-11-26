#!/usr/bin/env bash
#
# Sets HCL2JSON_SHA256 in the drift detection module to the hash of the
# hcl2json release it names, so a Renovate bump of HCL2JSON_VERSION doesn't
# leave the old hash behind. Renovate runs it after an update.
#
# Usage: update-hcl2json-sha.sh vX.Y.Z [FILE]

set -euo pipefail

version=${1:?usage: update-hcl2json-sha.sh vX.Y.Z [FILE]}
file=${2:-infra/modules/drift-detection/main.tf}

# Renovate fills the version in from a release tag, and it ends up in a URL
# and a command line.
if [[ ! ${version} =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Not a release version: ${version}" >&2
  exit 1
fi

dir=$(mktemp -d)
trap 'rm -rf "${dir}"' EXIT

curl -fsSL --retry 3 --max-time 120 \
  "https://github.com/tmccombs/hcl2json/releases/download/${version}/hcl2json_linux_amd64" \
  -o "${dir}/hcl2json"
sha=$(sha256sum "${dir}/hcl2json" | cut -d' ' -f1)

sed -i -E "s/(HCL2JSON_SHA256=\\\\\")[0-9a-f]{64}/\1${sha}/" "${file}"

if ! grep -q "HCL2JSON_SHA256=\\\\\"${sha}" "${file}"; then
  echo "Could not set HCL2JSON_SHA256 in ${file}" >&2
  exit 1
fi
echo "HCL2JSON_SHA256 for ${version} is ${sha}"
