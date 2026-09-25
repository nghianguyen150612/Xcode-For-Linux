#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-${PWD}}"
SOURCE_DIR="${2:-${ROOT_DIR}/.task002/darling-src}"
ARTIFACT_DIR="${3:-${ROOT_DIR}/artifacts/darling-baseline}"
CONFIG_FILE="${ROOT_DIR}/config/darling-baseline.env"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: Missing ${CONFIG_FILE}" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "ERROR: Task 002 requires a Linux host." >&2
    exit 1
fi
if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "ERROR: Task 002 requires an x86_64 host." >&2
    exit 1
fi

mkdir -p "$(dirname "${SOURCE_DIR}")" "${ARTIFACT_DIR}"

{
    echo "uname -a: $(uname -a)"
    echo "uname -m: $(uname -m)"
    if command -v lsb_release >/dev/null 2>&1; then
        echo "lsb_release:"
        lsb_release -a 2>&1 || true
    fi
    if [[ -r /etc/os-release ]]; then
        echo "/etc/os-release:"
        cat /etc/os-release
    fi
    echo "kernel.unprivileged_userns_clone: $(sysctl -n kernel.unprivileged_userns_clone 2>/dev/null || echo unavailable)"
} > "${ARTIFACT_DIR}/host.txt"

git lfs install --skip-repo >/dev/null

if [[ -e "${SOURCE_DIR}" ]]; then
    echo "ERROR: Source directory already exists: ${SOURCE_DIR}" >&2
    exit 1
fi

echo "Cloning Darling from ${DARLING_REPOSITORY}"
GIT_CLONE_PROTECTION_ACTIVE=false git clone --no-checkout "${DARLING_REPOSITORY}" "${SOURCE_DIR}"

git -C "${SOURCE_DIR}" checkout --detach "${DARLING_COMMIT}"
GIT_CLONE_PROTECTION_ACTIVE=false git -C "${SOURCE_DIR}" submodule update --init --recursive
git -C "${SOURCE_DIR}" lfs pull

ACTUAL_COMMIT="$(git -C "${SOURCE_DIR}" rev-parse HEAD)"
if [[ "${ACTUAL_COMMIT}" != "${DARLING_COMMIT}" ]]; then
    echo "ERROR: Darling source mismatch: expected ${DARLING_COMMIT}, got ${ACTUAL_COMMIT}" >&2
    exit 1
fi

{
    echo "repository=${DARLING_REPOSITORY}"
    echo "requested_commit=${DARLING_COMMIT}"
    echo "actual_commit=${ACTUAL_COMMIT}"
    echo "components=${DARLING_COMPONENTS}"
    echo "target_i386=${DARLING_TARGET_I386}"
    echo
    echo "submodules:"
    git -C "${SOURCE_DIR}" submodule status --recursive
} > "${ARTIFACT_DIR}/source.txt"

echo "Prepared Darling source at ${SOURCE_DIR}"
