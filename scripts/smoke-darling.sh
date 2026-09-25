#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-${PWD}}"
ARTIFACT_DIR="${2:-${ROOT_DIR}/artifacts/darling-baseline}"
PREFIX_DIR="${3:-${ROOT_DIR}/.task002/darling-prefix}"

mkdir -p "${ARTIFACT_DIR}/smoke" "${PREFIX_DIR}"
export DPREFIX="${PREFIX_DIR}"
export DSERVER_LOG_LEVEL=info

run_probe() {
    local name="$1"
    shift
    local out="${ARTIFACT_DIR}/smoke/${name}.txt"

    set +e
    timeout 120s darling shell "$@" >"${out}" 2>&1
    local status=$?
    set -e

    printf '%s\t%s\n' "${name}" "${status}" >> "${ARTIFACT_DIR}/smoke-results.tsv"

    if [[ "${status}" -ne 0 ]]; then
        echo "ERROR: Darling smoke probe '${name}' failed with exit code ${status}." >&2
        cat "${out}" >&2 || true
        return "${status}"
    fi
}

printf 'probe\texit_code\n' > "${ARTIFACT_DIR}/smoke-results.tsv"

run_probe uname /usr/bin/uname -a
run_probe sw_vers /usr/bin/sw_vers
run_probe arch /usr/bin/arch
run_probe shell_echo /bin/echo task-002-darling-baseline-ok

if [[ -f "${PREFIX_DIR}/private/var/log/dserver.log" ]]; then
    cp "${PREFIX_DIR}/private/var/log/dserver.log" "${ARTIFACT_DIR}/dserver.log"
fi

set +e
timeout 60s darling shutdown >"${ARTIFACT_DIR}/shutdown.txt" 2>&1
shutdown_status=$?
set -e
echo "shutdown_exit_code=${shutdown_status}" >> "${ARTIFACT_DIR}/shutdown.txt"

echo "Darling smoke baseline passed."
