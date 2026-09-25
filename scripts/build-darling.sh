#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-${PWD}}"
SOURCE_DIR="${2:-${ROOT_DIR}/.task002/darling-src}"
BUILD_DIR="${3:-${ROOT_DIR}/.task002/darling-build}"
ARTIFACT_DIR="${4:-${ROOT_DIR}/artifacts/darling-baseline}"
CONFIG_FILE="${ROOT_DIR}/config/darling-baseline.env"

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
    echo "ERROR: Darling source is not prepared at ${SOURCE_DIR}" >&2
    exit 1
fi

mkdir -p "${BUILD_DIR}" "${ARTIFACT_DIR}"

CMAKE_ARGS=(
    -S "${SOURCE_DIR}"
    -B "${BUILD_DIR}"
    "-DTARGET_i386=${DARLING_TARGET_I386}"
    "-DCOMPONENTS=${DARLING_COMPONENTS}"
)

{
    echo "cmake_version:"
    cmake --version
    echo
    echo "clang_version:"
    clang --version
    echo
    echo "configuration:"
    printf '%q ' cmake "${CMAKE_ARGS[@]}"
    printf '\n'
    echo "parallel_jobs=${DARLING_BUILD_JOBS:-$(nproc)}"
} > "${ARTIFACT_DIR}/build-config.txt"

cmake "${CMAKE_ARGS[@]}" 2>&1 | tee "${ARTIFACT_DIR}/configure.log"
cmake --build "${BUILD_DIR}" --parallel "${DARLING_BUILD_JOBS:-$(nproc)}" 2>&1 | tee "${ARTIFACT_DIR}/build.log"

sudo cmake --install "${BUILD_DIR}" 2>&1 | tee "${ARTIFACT_DIR}/install.log"

{
    echo "darling_path=$(command -v darling || true)"
    echo "installation_prefix=/usr/local"
    echo "build_completed=true"
} > "${ARTIFACT_DIR}/build-result.txt"

if ! command -v darling >/dev/null 2>&1; then
    echo "ERROR: Darling was installed but the darling launcher is not on PATH." >&2
    exit 1
fi
