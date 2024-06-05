#!/bin/bash
set -o errexit -o nounset -o pipefail
[[ "${TRACE:-0}" == "1" ]] && set -o xtrace

shepherd config location       "${API_ENDPOINT:?}"
shepherd login service-account "${API_TOKEN:?}"

if [[ -n "${RUN:-}" ]]; then
  echo "Running: ${RUN}"
  eval "${RUN}" # eval will always exit with whatever RUN returns, so the rest of main.sh won't execute if RUN is defined
fi

if [[ -n "${ENV_ID:-}" ]]; then
  echo "ENV_ID:    ${ENV_ID}"
  echo "NAMESPACE: ${NAMESPACE}"
  shepherd delete lease "${ENV_ID:?}" \
    --namespace "${NAMESPACE:?}"
fi

if [[ -n "${POOL_NAME:-}" ]]; then
  echo "POOL_NAME:      ${POOL_NAME}"
  echo "POOL_NAMESPACE: ${POOL_NAMESPACE}"

  create_lease() {
    shepherd create lease \
      --duration       "${DURATION:?}" \
      --pool           "${POOL_NAME:?}" \
      --pool-namespace "${POOL_NAMESPACE:?}" \
      --namespace      "${NAMESPACE:?}" \
      --description    "${DESCRIPTION:?}" \
      --json \
      | jq -r .id
  }

  get_lease() {
    shepherd get lease "${lease_id:?}" \
      --namespace "${NAMESPACE:?}" \
      --json \
      | jq -r \
          --sort-keys \
          --compact-output
  }

  wait_until_env_is_ready() {
    echo "::group::Lease readiness"
    while get_lease > lease.json; do
      status=$(jq -r .status lease.json )
      environment=$(jq -r --compact-output '.environment' lease.json)
      echo "[$(date -u +%Y-%m-%dT%H:%M:%S%Z)] Lease status: ${status:?} ${environment}"

      [[ "${TRACE:-0}" == "1" ]] && jq -r 'keys[] as $k | "\n\($k): \(.[$k] | tojson)"' lease.json

      case ${status} in
        LEASED)
          exit 0
          ;;
        FAILED | EXPIRED)
          exit 1
          ;;
        *)
          sleep 30
          ;;
      esac
    done
    echo "::endgroup::"
  }

  # lease_id="96255d59-e240-4215-a022-62ba4126bc18" # LEASED

  lease_id=${lease_id:-$(create_lease)}
  echo "env-id=$lease_id" >> "${GITHUB_OUTPUT}"

  time wait_until_env_is_ready
fi