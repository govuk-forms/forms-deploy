#!/usr/bin/env bash
#
# Runs Checkov against our Terraform. This is the one place its flags are
# set; `make checkov`, pre-commit and CI all call it.
#
# With no arguments, scans all of infra/. With changed file paths, scans the
# directories containing them: Checkov's graph checks and our own
# CKV2_FORMS_AWS_8 need to see every resource in a directory, so scanning
# single files misses problems that CI finds.

set -euo pipefail

cd "$(dirname "$0")/.."

# Without --skip-download Checkov tries to reach Prisma Cloud on every run and
# prints a stack trace when it can't.
checkov_flags=(
  --external-checks-dir infra/checkov/
  --framework terraform
  --quiet
  --skip-download
  --download-external-modules false
)

scan_dirs=()

if [ "$#" -eq 0 ]; then
  scan_dirs=(infra)
else
  for f in "$@"; do
    case "$f" in
      infra/checkov/*) scan_dirs=(infra); break ;;
    esac
  done

  if [ "${#scan_dirs[@]}" -eq 0 ]; then
    # Sorted, so parents come before their children. -d is recursive, so a
    # directory under one we already have is redundant.
    while IFS= read -r dir; do
      covered=false
      for kept in ${scan_dirs[@]+"${scan_dirs[@]}"}; do
        case "$dir/" in
          "$kept/"*) covered=true; break ;;
        esac
      done
      if [ "$covered" = false ]; then
        scan_dirs+=("$dir")
      fi
    done < <(for f in "$@"; do dirname "$f"; done | sort -u)
  fi
fi

dir_args=()
for dir in "${scan_dirs[@]}"; do
  dir_args+=(--directory "$dir")
done

exec checkov "${checkov_flags[@]}" "${dir_args[@]}"
