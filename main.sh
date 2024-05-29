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
      --namespace tas-devex \
      --json \
      | jq -r \
          --sort-keys \
          --compact-output
  }

  get_lease_status() {
    get_lease \
      | jq -r .status
  }

  get_lease_output() {
    get_lease \
      | jq -r .output \
           --sort-keys \
           --compact-output
  }

  wait_until_env_is_ready() {
    echo "::group::Lease readiness"
    while status=$(get_lease_status); do
      echo "[$(date -u +%Y-%m-%dT%H:%M:%S%Z)] Lease status: ${status:?}"
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

  # lease_id="63588369-ea60-422a-b4b9-9a1b2ada031c" # LEASED

  lease_id=${lease_id:-$(create_lease)}
  echo "env-id=$lease_id" >> "${GITHUB_OUTPUT}"

  get_lease > lease.json

  time wait_until_env_is_ready

  get_lease > lease.json
fi