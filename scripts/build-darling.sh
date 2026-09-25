#!/usr/bin/env bash
set -euo pipefail

# Script: build-darling.sh
# Purpose: Build Darling baseline reproducibly from pinned lockfile in third_party/darling.lock

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOCK_FILE="${REPO_ROOT}/third_party/darling.lock"
ARTIFACTS_DIR="${REPO_ROOT}/artifacts/darling-baseline"

mkdir -p "${ARTIFACTS_DIR}"

if [[ ! -f "${LOCK_FILE}" ]]; then
    echo "Error: Lock file not found at ${LOCK_FILE}" >&2
    exit 1
fi

# Parse lock file
DARLING_REPO="$(grep '^repository=' "${LOCK_FILE}" | cut -d'=' -f2-)"
DARLING_COMMIT="$(grep '^commit=' "${LOCK_FILE}" | cut -d'=' -f2-)"

if [[ -z "${DARLING_REPO}" || -z "${DARLING_COMMIT}" ]]; then
    echo "Error: Failed to parse repository or commit from ${LOCK_FILE}" >&2
    exit 1
fi

echo "=== Darling Build Configuration ==="
echo "Repository: ${DARLING_REPO}"
echo "Requested Commit: ${DARLING_COMMIT}"
echo "=================================="

# Record Host Information
{
    echo "=== Host System Information ==="
    echo "Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "Hostname: $(hostname 2>/dev/null || echo 'unknown')"
    echo "OS Kernel: $(uname -a)"
    echo "Architecture: $(uname -m)"
    if [[ -f /etc/os-release ]]; then
        echo "--- /etc/os-release ---"
        cat /etc/os-release
    fi
    echo "--- Tool Versions ---"
    echo "ldd: $(ldd --version 2>&1 | head -n 1)"
    echo "gcc: $(gcc --version 2>&1 | head -n 1)"
    echo "clang: $(clang --version 2>&1 | head -n 1 || echo 'not installed')"
    echo "cmake: $(cmake --version 2>&1 | head -n 1)"
    echo "ninja: $(ninja --version 2>&1 | head -n 1 || echo 'not installed')"
    echo "python3: $(python3 --version 2>&1)"
    echo "git: $(git --version 2>&1)"
    echo "--- Disk Space ---"
    df -h .
} > "${ARTIFACTS_DIR}/host.txt"

# Verify x86_64 architecture
if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "Error: Host architecture is $(uname -m), but x86_64 is required." >&2
    exit 1
fi

BUILD_WORK_DIR="${REPO_ROOT}/build/darling-build-workspace"
rm -rf "${BUILD_WORK_DIR}"
mkdir -p "${BUILD_WORK_DIR}"

cd "${BUILD_WORK_DIR}"

echo "Cloning Darling source..."
git clone "${DARLING_REPO}" darling-src
cd darling-src

echo "Checking out pinned commit: ${DARLING_COMMIT}..."
git checkout --detach "${DARLING_COMMIT}"

ACTUAL_HEAD="$(git rev-parse HEAD)"
if [[ "${ACTUAL_HEAD}" != "${DARLING_COMMIT}" ]]; then
    echo "Error: Checked out commit (${ACTUAL_HEAD}) does not match pinned commit (${DARLING_COMMIT})" >&2
    exit 1
fi

echo "Initializing git submodules recursively..."
git submodule sync --recursive
git submodule update --init --recursive

# Record Source Metadata
{
    echo "Upstream Repository: ${DARLING_REPO}"
    echo "Requested Commit: ${DARLING_COMMIT}"
    echo "Actual HEAD Commit: ${ACTUAL_HEAD}"
    echo "Git Branch/State: $(git symbolic-ref -q --short HEAD || echo 'detached HEAD')"
    echo "Git Status:"
    git status --short
} > "${ARTIFACTS_DIR}/darling-source.txt"

git submodule status --recursive > "${ARTIFACTS_DIR}/submodules.txt"

# Dependency Installation
echo "Installing build dependencies from debian/control..."
SUDO_CMD=""
if command -v sudo >/dev/null 2>&1; then
    SUDO_CMD="sudo"
fi

{
    echo "=== Updating Apt Repositories ==="
    ${SUDO_CMD} apt-get update -y || true

    echo "=== Installing Build Helpers ==="
    ${SUDO_CMD} apt-get install -y devscripts equivs debhelper

    echo "=== Satisfying Build Dependencies from debian/control ==="
    ${SUDO_CMD} mk-build-deps -i -r -t "apt-get --no-install-recommends -y" debian/control
} > "${ARTIFACTS_DIR}/dependencies.txt" 2>&1 || {
    echo "Warning or failure during dependency resolution. Check dependencies.txt." >&2
}

# Execute Build
BUILD_START_TIME=$(date +%s)
echo "Building Darling packages using ./tools/debian/make-deb..."

{
    echo "Build Start Time: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    ./tools/debian/make-deb
    echo "Build End Time: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
} > "${ARTIFACTS_DIR}/build.txt" 2>&1 || {
    BUILD_END_TIME=$(date +%s)
    echo "Build failed after $((BUILD_END_TIME - BUILD_START_TIME)) seconds. See ${ARTIFACTS_DIR}/build.txt" >&2
    exit 1
}

BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
echo "Build succeeded in ${BUILD_DURATION} seconds."
echo "Build Duration: ${BUILD_DURATION} seconds" >> "${ARTIFACTS_DIR}/build.txt"

# Record Inventory of Produced .deb Packages
echo -e "filename\tsize\tsha256\tpackage_name\tpackage_version\tarchitecture" > "${ARTIFACTS_DIR}/packages.tsv"

DEB_FILES=( "${BUILD_WORK_DIR}"/*.deb )
if [[ ${#DEB_FILES[@]} -eq 0 || ! -f "${DEB_FILES[0]}" ]]; then
    echo "Error: No .deb packages found in ${BUILD_WORK_DIR}" >&2
    exit 1
fi

echo "Found ${#DEB_FILES[@]} generated .deb package(s)."

for deb in "${BUILD_WORK_DIR}"/*.deb; do
    if [[ -f "${deb}" ]]; then
        fname="$(basename "${deb}")"
        fsize="$(stat -c%s "${deb}")"
        fhash="$(sha256sum "${deb}" | awk '{print $1}')"
        pkg_name="$(dpkg-deb -f "${deb}" Package 2>/dev/null || echo 'unknown')"
        pkg_ver="$(dpkg-deb -f "${deb}" Version 2>/dev/null || echo 'unknown')"
        pkg_arch="$(dpkg-deb -f "${deb}" Architecture 2>/dev/null || echo 'unknown')"
        echo -e "${fname}\t${fsize}\t${fhash}\t${pkg_name}\t${pkg_ver}\t${pkg_arch}" >> "${ARTIFACTS_DIR}/packages.tsv"
    fi
done

echo "Darling build complete and inventoried."
