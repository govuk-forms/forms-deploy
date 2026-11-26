#!/usr/bin/env bash
#
# Checks that the images Renovate looks up on Docker Hub but we pull from ECR or
# ghcr (see .github/renovate.json5) are the same image: the tag exists in both,
# both serve the same digest, and a digest in the pin is that digest. The ECR
# copies are mirrors filled in by their publishers and can lag Docker Hub. Age
# is Renovate's job. Pins with no Docker Hub copy are skipped.
#
# Usage: check-image-pins.sh [FILE...]
# Defaults to every Terraform file tracked by git, and the pre-commit config.

set -euo pipefail

ACCEPT="application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json"

# Prints the Docker Hub repository that holds the same image as a repository
# on ECR or ghcr, if we look it up there.
hub_repository() {
  case "$1/$2" in
  public.ecr.aws/docker/library/*) echo "library/${2#docker/library/}" ;;
  public.ecr.aws/aws-observability/aws-otel-collector) echo "amazon/aws-otel-collector" ;;
  ghcr.io/renovatebot/renovate) echo "renovate/renovate" ;;
  esac
}

ECR_TOKEN=""
REGISTRY_STATUS=""
REGISTRY_DIGEST=""

# Sets REGISTRY_DIGEST for a tag. Returns 1 if the tag doesn't exist and 2 if
# the registry gave no clear answer, with REGISTRY_STATUS holding its last
# status. Anything but 200 or 404 is retried, because anonymous requests from a
# shared address are sometimes throttled. Call it directly and not in $(...),
# which would lose the variables.
registry_digest() {
  local host=$1 repo=$2 tag=$3 token headers attempt
  REGISTRY_STATUS=""
  REGISTRY_DIGEST=""
  for attempt in 1 2 3; do
    token=""
    case "${host}" in
    public.ecr.aws)
      if [[ -z ${ECR_TOKEN} ]]; then
        ECR_TOKEN=$(curl -fsS --max-time 30 "https://public.ecr.aws/token/" | jq -r .token) || ECR_TOKEN=""
      fi
      token=${ECR_TOKEN}
      ;;
    ghcr.io)
      token=$(curl -fsS --max-time 30 "https://ghcr.io/token?scope=repository:${repo}:pull" | jq -r .token) || token=""
      ;;
    esac
    if [[ -n ${token} ]]; then
      headers=$(curl -sS -I --max-time 30 \
        -H "Authorization: Bearer ${token}" -H "Accept: ${ACCEPT}" \
        "https://${host}/v2/${repo}/manifests/${tag}" | tr -d '\r') || headers=""
      REGISTRY_STATUS=$(awk 'NR == 1 {print $2}' <<<"${headers}")
      case "${REGISTRY_STATUS}" in
      200)
        REGISTRY_DIGEST=$(awk 'tolower($1) == "docker-content-digest:" {print $2}' <<<"${headers}")
        return 0
        ;;
      404) return 1 ;;
      401) ECR_TOKEN="" ;;
      esac
    fi
    sleep $((attempt * 3))
  done
  return 2
}

# Prints Docker Hub's body for a tag, then its HTTP status on the last line.
# Retried like the registry call.
hub_tag() {
  local hub=$1 tag=$2 answer status attempt
  for attempt in 1 2 3; do
    answer=$(curl -sS --max-time 30 -w '\n%{http_code}' "https://hub.docker.com/v2/repositories/${hub}/tags/${tag}") || answer=$'\n000'
    status=${answer##*$'\n'}
    if [[ ${status} == 200 || ${status} == 404 ]]; then
      break
    fi
    sleep $((attempt * 3))
  done
  echo "${answer}"
}

failures=0
checked=0
fail() {
  echo "FAIL  $1"
  echo "      $2"
  failures=$((failures + 1))
}

check_pin() {
  local pin=$1 host rest pinned_digest="" repo tag hub status body hub_status hub_sha

  host=${pin%%/*}
  rest=${pin#*/}
  if [[ ${rest} == *@sha256:* ]]; then
    pinned_digest=${rest#*@}
    rest=${rest%@*}
  fi
  repo=${rest%:*}
  tag=${rest##*:}

  hub=$(hub_repository "${host}" "${repo}")
  if [[ -z ${hub} ]]; then
    return
  fi
  checked=$((checked + 1))

  if [[ -n ${pinned_digest} && ! ${pinned_digest} =~ ^sha256:[0-9a-f]{64}$ ]]; then
    fail "${pin}" "${pinned_digest} is not a sha256 digest of 64 hex characters."
    return
  fi

  body=$(hub_tag "${hub}" "${tag}")
  hub_status=${body##*$'\n'}
  body=${body%$'\n'*}
  case "${hub_status}" in
  200) ;;
  404)
    fail "${pin}" "Docker Hub has no tag ${hub}:${tag}, so this is not an image Renovate looked up."
    return
    ;;
  *)
    fail "${pin}" "Docker Hub would not say whether ${hub}:${tag} exists (HTTP ${hub_status}). Run this again."
    return
    ;;
  esac
  hub_sha=$(jq -r .digest <<<"${body}")

  if registry_digest "${host}" "${repo}" "${tag}"; then
    status=0
  else
    status=$?
  fi
  case "${status}" in
  1)
    fail "${pin}" "${hub}:${tag} is on Docker Hub but not on ${host} yet, so the mirror is behind."
    return
    ;;
  2)
    fail "${pin}" "${host} would not say whether the tag exists (HTTP ${REGISTRY_STATUS:-no answer}). Run this again."
    return
    ;;
  esac

  if [[ ${REGISTRY_DIGEST} != "${hub_sha}" ]]; then
    fail "${pin}" "${host} serves ${REGISTRY_DIGEST} but Docker Hub serves ${hub_sha} for ${hub}:${tag}."
    return
  fi
  if [[ -n ${pinned_digest} && ${pinned_digest} != "${hub_sha}" ]]; then
    fail "${pin}" "The pin says ${pinned_digest} but ${tag} is ${hub_sha} on ${host} and Docker Hub."
    return
  fi

  echo "ok    ${pin}  (same digest as Docker Hub)"
}

if (($# > 0)); then
  files=("$@")
else
  files=(.pre-commit-config.yaml)
  while IFS= read -r file; do
    files+=("${file}")
  done < <(git ls-files '*.tf')
fi

# grep exits 1 when nothing matches, which is fine, and 2 when it can't read a file.
found=$(grep -ohE '(public\.ecr\.aws|ghcr\.io)/[A-Za-z0-9._/-]+:[A-Za-z0-9._-]+(@sha256:[0-9a-f]+)?' "${files[@]}") && status=0 || status=$?
if ((status > 1)); then
  echo "Could not read the files to check." >&2
  exit 2
fi
pins=$(sort -u <<<"${found}")

while IFS= read -r pin; do
  if [[ -n ${pin} ]]; then
    check_pin "${pin}"
  fi
done <<<"${pins}"

if ((checked == 0)); then
  echo "No images pinned on ECR or ghcr that are looked up on Docker Hub."
fi

if ((failures > 0)); then
  echo
  echo "${failures} image pin(s) failed. This check is run again every half hour, which clears a mirror that was behind."
  exit 1
fi
