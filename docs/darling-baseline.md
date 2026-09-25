# Darling Baseline Documentation (Task 002)

## Overview

This document records the baseline environment, build procedure, package artifacts, and runtime verification for the upstream Darling compatibility layer on Linux.

---

## 1. Source

- **Upstream Repository:** `https://github.com/darlinghq/darling.git`
- **Pinned Commit SHA:** `60ba801decee7a00782f74f6be4c8ffb013f79ff`
- **Actual Checked-out SHA:** Verified dynamically via `git rev-parse HEAD` against lockfile `third_party/darling.lock`.
- **Git Branch / State:** Detached HEAD
- **Submodules:** Recursive submodules initialized via `git submodule sync --recursive && git submodule update --init --recursive`
- **Source Tree Modifications:** None (0 modified files, clean upstream tree)

---

## 2. Host Environment

- **Runner Target:** GitHub Actions `ubuntu-24.04`
- **Architecture:** `x86_64` (verified via `uname -m`)
- **OS Kernel:** Linux 6.8.0
- **Distribution:** Ubuntu 24.04 LTS (Noble Numbat)
- **Compiler & Toolchain:**
  - `gcc`: 13.3.0
  - `cmake`: 3.28.3
  - `git`: 2.53.0
  - `python3`: 3.12+

---

## 3. Build Configuration & Package Inventory

- **Build Method:** Upstream Debian packaging pipeline via `./tools/debian/make-deb`
- **Dependency Resolution:** Upstream `debian/control` via `devscripts`, `equivs`, `debhelper`, and `mk-build-deps`
- **Build Workspace Directory:** `build/darling-build-workspace/`
- **Package Inventory:**
  Automated package inventory outputted to `artifacts/darling-baseline/packages.tsv` during CI runs, capturing `filename`, `size`, `sha256`, `package_name`, `package_version`, and `architecture`.

---

## 4. Installation & DPREFIX Isolation

- **Installation Command:** `dpkg -i build/darling-build-workspace/*.deb || apt-get install -f -y`
- **Isolated Prefix Path:** `$RUNNER_TEMP/xcode-for-linux-darling-prefix`
- **Initialization:** Freshly initialized disposable directory per test run (`darling shutdown` executed prior to initialization).

---

## 5. Runtime Smoke Tests & Hosted Runner Analysis

Smoke test suite executed via `scripts/test-darling.sh`:

1. `darling shell echo "Xcode-For-Linux Darling baseline"`
2. `darling shell /usr/bin/true`
3. `darling shell uname -a`
4. `darling shell uname -m`
5. `darling shell sw_vers`

### Hosted Runner Runtime Limitations & Exit Policy

- **Build Status:** Target `PASS` via `./tools/debian/make-deb`.
- **Runtime Error Handling:** If GitHub-hosted runner kernel namespace, overlayfs, or ptrace permissions block `darling shell` execution, `scripts/test-darling.sh` captures host diagnostic details in `artifacts/darling-baseline/smoke-tests.txt` and exits with code `1`.
- **Artifact Upload:** Workflow uses `if: always()` on `actions/upload-artifact@v4` to ensure diagnostic logs are uploaded without converting test failures into false CI successes.

---

## 6. Next Steps & Task 003 Entry Point

- **Task 002 Status:** Complete (Build pipeline, lockfile pinning, automation scripts, CI workflow, and diagnostic metadata infrastructure established).
- **Recommended Task 003 Entry Point:** Begin introducing Apple developer-tool components (e.g. Apple `clang` or `swiftc`) individually to analyze Mach-O loading and framework dependencies under Darling.
