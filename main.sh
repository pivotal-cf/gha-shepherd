#!/bin/bash
set -o errexit -o nounset -o pipefail
[[ "${TRACE:-0}" == "1" ]] && set -o xtrace

shepherd config location       "${API_ENDPOINT:?}"
shepherd login service-account "${API_TOKEN:?}"

run_shell_with_authenticated_shepherd() {
  echo "Running: ${RUN:?}"
  eval "${RUN:?}" # eval will always exit with whatever RUN returns, so the rest of main.sh won't execute if RUN is defined
}

delete_lease() {
  echo "ENV_ID:    ${ENV_ID:?}"
  echo "NAMESPACE: ${NAMESPACE:?}"
  shepherd delete lease "${ENV_ID:?}" \
    --namespace "${NAMESPACE:?}"
}

create_lease() {
  echo "DESCRIPTION:    ${DESCRIPTION:?}"
  echo "DURATION:       ${DURATION:?}"
  echo "NAMESPACE:      ${NAMESPACE:?}"
  echo "POOL_NAME:      ${POOL_NAME:?}"
  echo "POOL_NAMESPACE: ${POOL_NAMESPACE:?}"

  new_lease_id=${ENV_ID:-$(
    shepherd create lease \
      --description    "${DESCRIPTION:?}" \
      --duration       "${DURATION:?}" \
      --namespace      "${NAMESPACE:?}" \
      --pool           "${POOL_NAME:?}" \
      --pool-namespace "${POOL_NAMESPACE:?}" \
      --json \
    | jq -r .id
  )}

  echo "env-id=$new_lease_id" >> "${GITHUB_OUTPUT}"
}

get_lease() {
  new_lease_id=${ENV_ID:-$(create_lease)}
  shepherd get lease "${new_lease_id:? Provide ENV_ID of the existing environment}" \
    --namespace "${NAMESPACE:?}" \
    --json \
  | jq -r \
      --sort-keys \
      --compact-output
}

wait_until_env_is_ready() {
  mkdir -p "$(dirname "${ENV_FILE_PATH:?}")"
  echo "::group::Lease readiness"
  while get_lease > "${ENV_FILE_PATH:?}"; do
    status=$(jq -r .status "${ENV_FILE_PATH:?}")
    status_msg=$(jq -r .status_msg "${ENV_FILE_PATH:?}" || true )
    environment=$(jq -r --compact-output '.environment' "${ENV_FILE_PATH:?}")
    echo "[$(date -u +%Y-%m-%dT%H:%M:%S%Z)] Lease status: ${status:?}: ${status_msg}"
    echo "::debug:: ${environment}"
    [[ "${TRACE:-0}" == "1" ]] && jq -r 'keys[] as $k | "\n::debug:: \($k): \(.[$k] | tojson)"' lease.json
    case ${status} in
      LEASED)           exit 0 ;;
      FAILED | EXPIRED) exit 1 ;;
      *)                sleep 30 ;;
    esac
  done
  echo "::endgroup::"
}

case ${COMMAND:?} in
  shell)  run_shell_with_authenticated_shepherd ;;
  create) create_lease ;;
  get)    wait_until_env_is_ready ;;
  delete) delete_lease ;;
  *)      echo "::error:: Unsupported command: ${COMMAND}"; exit 1 ;;
esac
