#!/usr/bin/env bash
set -euo pipefail

# Script: test-darling.sh
# Purpose: Install built Darling packages, initialize an isolated DPREFIX, and run minimal runtime smoke tests.

export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARTIFACTS_DIR="${REPO_ROOT}/artifacts/darling-baseline"
BUILD_WORK_DIR="${REPO_ROOT}/build/darling-build-workspace"

mkdir -p "${ARTIFACTS_DIR}"

SUDO_CMD=""
if command -v sudo >/dev/null 2>&1; then
    SUDO_CMD="sudo"
fi

echo "=== Installing Built Darling Packages ==="
{
    echo "=== Installing .deb packages from ${BUILD_WORK_DIR} ==="
    DEB_FILES=( "${BUILD_WORK_DIR}"/*.deb )
    if [[ ${#DEB_FILES[@]} -gt 0 && -f "${DEB_FILES[0]}" ]]; then
        ${SUDO_CMD} dpkg -i "${BUILD_WORK_DIR}"/*.deb || ${SUDO_CMD} apt-get install -f -y
    else
        echo "No local .deb packages found in ${BUILD_WORK_DIR}. Checking if darling is already installed..."
    fi
    echo "--- Command Location ---"
    which darling || echo "darling executable not found in PATH"
    echo "--- Installed Darling Packages ---"
    dpkg -l | grep darling || echo "No darling dpkg packages listed"
} > "${ARTIFACTS_DIR}/install.txt" 2>&1

if ! command -v darling >/dev/null 2>&1; then
    echo "Error: 'darling' binary is not installed or available in PATH." >&2
    exit 1
fi

# Isolated DPREFIX setup
PREFIX_DIR="${RUNNER_TEMP:-/tmp}/xcode-for-linux-darling-prefix"
rm -rf "${PREFIX_DIR}"
mkdir -p "${PREFIX_DIR}"

export DPREFIX="${PREFIX_DIR}"

echo "=== Initializing Disposable Isolated DPREFIX ==="
{
    echo "DPREFIX Path: ${DPREFIX}"
    echo "Filesystem Type: $(df -T "${DPREFIX}" | tail -n 1 | awk '{print $2}')"
    echo "Initializing Darling prefix..."
    darling shutdown || true
} > "${ARTIFACTS_DIR}/prefix.txt" 2>&1

# Run Runtime Smoke Tests
echo "=== Running Darling Runtime Smoke Tests ==="

run_smoke_cmd() {
    local label="$1"
    shift
    echo "--------------------------------------------------" >> "${ARTIFACTS_DIR}/smoke-tests.txt"
    echo "Command: $*" >> "${ARTIFACTS_DIR}/smoke-tests.txt"
    set +e
    "$@" >> "${ARTIFACTS_DIR}/smoke-tests.txt" 2>&1
    local rc=$?
    set -e
    echo "Exit Code: ${rc}" >> "${ARTIFACTS_DIR}/smoke-tests.txt"
    return ${rc}
}

{
    echo "=== Darling Runtime Smoke Test Results ==="
    echo "Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "DPREFIX: ${DPREFIX}"
} > "${ARTIFACTS_DIR}/smoke-tests.txt"

SMOKE_PASSED=true

run_smoke_cmd "echo" darling shell echo "Xcode-For-Linux Darling baseline" || SMOKE_PASSED=false
run_smoke_cmd "true" darling shell /usr/bin/true || SMOKE_PASSED=false
run_smoke_cmd "uname-a" darling shell uname -a || SMOKE_PASSED=false
run_smoke_cmd "uname-m" darling shell uname -m || SMOKE_PASSED=false
run_smoke_cmd "sw_vers" darling shell sw_vers || SMOKE_PASSED=false

echo "--------------------------------------------------" >> "${ARTIFACTS_DIR}/smoke-tests.txt"
if [[ "${SMOKE_PASSED}" == "true" ]]; then
    echo "OVERALL SMOKE TEST RESULT: PASS" >> "${ARTIFACTS_DIR}/smoke-tests.txt"
    echo "Darling runtime smoke tests passed."
else
    echo "OVERALL SMOKE TEST RESULT: FAIL / BLOCKED" >> "${ARTIFACTS_DIR}/smoke-tests.txt"
    echo "Warning: Darling runtime smoke tests failed or were blocked. Details captured in ${ARTIFACTS_DIR}/smoke-tests.txt."
fi

# Diagnostic capture if failed
if [[ "${SMOKE_PASSED}" == "false" ]]; then
    {
        echo "=== Host Runtime Limitation Diagnostic Analysis ==="
        echo "Checking potential container/host kernel limitations..."
        echo "--- Kernel Version & Architecture ---"
        uname -a
        echo "--- Overlayfs / FUSE / Mount Capabilities ---"
        grep -E 'overlay|fuse|overlayfs' /proc/filesystems || true
        echo "--- dmesg / Kernel Logs (last 20 lines) ---"
        dmesg 2>/dev/null | tail -n 20 || echo "dmesg restricted or unavailable"
    } >> "${ARTIFACTS_DIR}/smoke-tests.txt" 2>&1

    # Exit non-zero so CI accurately reflects runtime test failures
    exit 1
fi
