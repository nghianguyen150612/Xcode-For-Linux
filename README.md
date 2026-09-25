# Xcode-For-Linux

`Xcode-For-Linux` is an experimental research and compatibility project aimed at investigating the requirements for running Apple's original Xcode IDE and related developer tools on Linux using compatibility layers such as Darling.

---

## Current Project Status

- **Phase 0 (Research & Baseline Inventory):** Active.
- **Task 001:** Complete — Xcode 16.4 `x86_64` baseline validated on a real Intel macOS GitHub Actions runner and documented from inspected artifacts.
- **Task 002:** Complete — Established reproducible Darling baseline on Linux from pinned commit `60ba801decee7a00782f74f6be4c8ffb013f79ff` (`BUILD BASELINE: PASS`; `RUNTIME BASELINE: BLOCKED BY GitHub-hosted runner kernel namespace / overlayfs restrictions`).
- **Task 003:** Next — Introduce Apple developer-tool components one component at a time and attribute compatibility gaps.

---

## Legal Boundary & Disclaimer

- **No Proprietary Code or Binaries:** This repository does **not** host, commit, or redistribute Apple Xcode, Apple SDKs, Apple Frameworks, Simulator runtimes, or any extracted proprietary binaries.
- **Non-Affiliation:** This project is an independent open-source research initiative and is **not** affiliated with, authorized, maintained, sponsored, or endorsed by Apple Inc.
- **Intellectual Property:** Apple, Xcode, macOS, Swift, and iOS are trademarks of Apple Inc.

---

## Architecture & Roadmap

For more details on the planned compatibility architecture and research milestones, please consult:
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/ROADMAP.md](docs/ROADMAP.md)
- [docs/xcode-16.4-baseline.md](docs/xcode-16.4-baseline.md)
- [docs/darling-baseline.md](docs/darling-baseline.md)
