#!/usr/bin/env bash

#quit if exit status of any cmd is a non-zero value
set -euo pipefail

precheck_params() {
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

# Update SprayProxy URL in the GitHub App
setup_githubapp() {
    # Inspired by implementation by Will Haley at:
    #   http://willhaley.com/blog/generate-jwt-with-bash/

    # Shared content to use as template
    header_template='{
        "typ": "JWT",
        "kid": "0001",
        "iss": "https://stackoverflow.com/questions/46657001/how-do-you-create-an-rs256-jwt-assertion-with-bash-shell-scripting"
        }'

    now=$(date +%s)
    build_header() {
        jq -c \
            --arg iat_str "$now" \
            --arg alg "${1:-HS256}" \
            '
                ($iat_str | tonumber) as $iat
                | .alg = $alg
                | .iat = $iat
                | .exp = ($iat + 10)
                ' <<<"$header_template" | tr -d '\n'
    }

    b64enc() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }
    json() { jq -c . | LC_CTYPE=C tr -d '\n'; }
    hs_sign() { openssl dgst -binary -sha"${1}" -hmac "$2"; }
    rs_sign() { openssl dgst -binary -sha"${1}" -sign <(printf '%s\n' "$2"); }

    sign() {
        local algo payload header sig secret=$3
        algo=${1:-RS256}
        algo=${algo^^}
        header=$(build_header "$algo") || return
        payload=${2:-$test_payload}
        signed_content="$(json <<<"$header" | b64enc).$(json <<<"$payload" | b64enc)"
        case $algo in
        HS*) sig=$(printf %s "$signed_content" | hs_sign "${algo#HS}" "$secret" | b64enc) ;;
        RS*) sig=$(printf %s "$signed_content" | rs_sign "${algo#RS}" "$secret" | b64enc) ;;
        *)
            echo "Unknown algorithm" >&2
            return 1
            ;;
        esac
        printf '%s.%s\n' "${signed_content}" "${sig}"
    }
    payload="{ \"iss\": $PAC_GITHUB_APP_ID, \"iat\": ${now}, \"exp\": $((now + 10)) }"

    token=$(sign rs256 "$payload" "$(echo "$PAC_GITHUB_APP_PRIVATE_KEY" | base64 -d)")

    curl \
        -X PATCH \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: Bearer $token" \
        https://api.github.com/app/hook/config \
        -d "{\"url\":\"https://$sprayproxy_route/proxy\"}" &>/dev/null
}

update_values_in_vault() {
    vault kv patch kv/selfservice/redhat-appstudio-qe/ci-secrets qe-sprayproxy-token="$sprayproxy_token" qe-sprayproxy-host="https://$sprayproxy_route"
}

retrieve_sprayproxy_data() {
    sprayproxy_route=$(kubectl get route sprayproxy-route -n sprayproxy -o jsonpath='{.spec.host}')
    sprayproxy_token=$(kubectl exec -n sprayproxy "$(kubectl get pods -n sprayproxy -o name)" -c kube-rbac-proxy -i -t -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)
}

main() {
    precheck_params
    retrieve_sprayproxy_data
    setup_githubapp
    update_values_in_vault
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
    main "$@"
fi
