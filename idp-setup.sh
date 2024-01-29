#!/usr/bin/env bash

#quit if exit status of any cmd is a non-zero value
set -euo pipefail

ORGS="redhat-appstudio-qe"

# pre-check params to ensure they are set, the params includs the following:
# GITHUB_APP_CLIENT_ID, GITHUB_APP_CLIENT_SECRET, CLUSTER_NAME
precheck_params() {
    GITHUB_APP_CLIENT_ID="${GITHUB_APP_CLIENT_ID:-}"
    if [[ -z "$GITHUB_APP_CLIENT_ID" ]]; then
        echo "ERROR: Variable 'GITHUB_APP_CLIENT_ID' was not exported"
        exit 1
    fi

    GITHUB_APP_CLIENT_SECRET="${GITHUB_APP_CLIENT_SECRET:-}"
    if [[ -z "$GITHUB_APP_CLIENT_SECRET" ]]; then
        echo "ERROR: Variable 'GITHUB_APP_CLIENT_SECRET' was not exported"
        exit 1
    fi
    CLUSTER_NAME="${CLUSTER_NAME:-}"
    if [[ -z "$CLUSTER_NAME" ]]; then
        echo "ERROR: Variable 'CLUSTER_NAME' was not exported"
        exit 1
    fi
}

# Add Github IDP to determine how users log into the cluster
dedicated_admins=("xinredhat" "psturc" "prietyc123" "rhopp")
add_github_idp() {
    output="/tmp/idp_output.txt"
    rosa create idp --type=github --cluster="$CLUSTER_NAME" --client-id="$GITHUB_APP_CLIENT_ID" --client-secret="$GITHUB_APP_CLIENT_SECRET" --organizations="$ORGS" | tee "$output"
    callback_uri=$(grep "Callback URI" "$output"| cut -d " " -f 4)
    for user in "${dedicated_admins[@]}"; do
        rosa grant user dedicated-admin --user="$user" --cluster="$CLUSTER_NAME"
    done

    echo "Please update the callback URL to the Github App: $callback_uri"
}

main() {
    precheck_params
    add_github_idp
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
