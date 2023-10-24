#!/usr/bin/env bash

#quit if exit status of any cmd is a non-zero value
set -euo pipefail

SCRIPT_DIR="$(
  cd "$(dirname "$0")" >/dev/null
  pwd
)"

NAMESPACE="sprayproxy"

precheck_params() {
  WEBHOOK_SECRET="${WEBHOOK_SECRET:-}"
  if [ -z "$WEBHOOK_SECRET" ]; then
    echo "ERROR: Variable 'WEBHOOK_SECRET' was not exported"
    exit 1
  fi

  PAC_GITHUB_APP_PRIVATE_KEY="${PAC_GITHUB_APP_PRIVATE_KEY:-}"
  if [[ -z "$PAC_GITHUB_APP_PRIVATE_KEY" ]]; then
    echo "ERROR: Variable 'PAC_GITHUB_APP_PRIVATE_KEY' was not exported"
    exit 1
  fi

  PAC_GITHUB_APP_ID="${PAC_GITHUB_APP_ID:-}"
  if [[ -z "$PAC_GITHUB_APP_ID" ]]; then
    echo "ERROR: Variable 'PAC_GITHUB_APP_ID' was not exported"
    exit 1
  fi
}

deploy() {
  # Deploy SprayProxy
  kubectl apply -k "$SCRIPT_DIR"/config

  # Create pipelines-as-code-secret
  kubectl -n "$NAMESPACE" delete secret pipelines-as-code-secret || true
  kubectl -n "$NAMESPACE" create secret generic pipelines-as-code-secret \
    --from-literal github-private-key="$(echo "$PAC_GITHUB_APP_PRIVATE_KEY" | base64 -d)" \
    --from-literal github-application-id="$PAC_GITHUB_APP_ID" \
    --from-literal webhook.secret="$WEBHOOK_SECRET"

  # Wait for SprayProxy to be ready
  kubectl wait --for=condition=available --timeout=300s deployment/sprayproxy -n "$NAMESPACE"
}

main() {
  precheck_params
  deploy
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi
