#!/usr/bin/env bash

#quit if exit status of any cmd is a non-zero value
set -euo pipefail
set -x

SCRIPT_DIR="$(
    cd "$(dirname "$0")" >/dev/null
    pwd
)"

retrieve_params_from_vault() {
    secrets=$(vault kv get -format=json kv/selfservice/redhat-appstudio-qe/ci-secrets)
    PAC_GITHUB_APP_ID=$(echo "${secrets}" | jq -r '.data.data."pac-github-app-id"')
    WEBHOOK_SECRET=$(echo "${secrets}" | jq -r '.data.data."pac-github-app-webhook-secret"')
    PAC_GITHUB_APP_PRIVATE_KEY=$(echo "${secrets}" | jq -r '.data.data."pac-github-app-private-key"')

    export PAC_GITHUB_APP_ID WEBHOOK_SECRET PAC_GITHUB_APP_PRIVATE_KEY
}

# if there are no parameters when running main.sh, it will run all referenced scripts, i.e. deploy-sprayproxy.sh and setup.sh
# if there are parameters when running main.sh, it will only execute the one which is specified by the parameter.
main() {
    retrieve_params_from_vault
    if [ $# -eq 0 ]; then
        "$SCRIPT_DIR"/deploy-sprayproxy.sh
        "$SCRIPT_DIR"/setup.sh
    else
        case $1 in
        deploy)
            "$SCRIPT_DIR"/deploy-sprayproxy.sh
            ;;
        setup)
            "$SCRIPT_DIR"/setup.sh
            ;;
        *)
            echo "Usage: $0 [deploy|setup]"
            exit 1
            ;;
        esac
    fi
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
    main "$@"
fi
