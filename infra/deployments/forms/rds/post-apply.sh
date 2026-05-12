#!/usr/bin/env bash

set -euo pipefail

echo "Checking for user-created RDS secrets to clean up..."

mapfile -t user_secrets < <(
    aws secretsmanager list-secrets --no-include-planned-deletion --no-paginate \
        --filter Key=name,Values=rds-db-credentials/ |
        jq -r '.SecretList[].Name | select(test("^rds-db-credentials/cluster-\\w+/[\\w-]+/\\d+$"))'
)

if [[ ${#user_secrets[@]} -eq 0 ]]; then
    echo "No user-created secrets found."
    exit 0
fi

echo "Found ${#user_secrets[@]} user-created secret(s) to delete:"

for secret_name in "${user_secrets[@]}"; do
    echo "  Deleting: ${secret_name}"
    aws secretsmanager delete-secret \
        --secret-id "${secret_name}" \
        --recovery-window-in-days 30
done

echo "Done."
