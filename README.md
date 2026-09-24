# Xcode-For-Linux

`Xcode-For-Linux` is an experimental research and compatibility project investigating what is required to run Apple's original Xcode IDE and related developer tools on Linux through compatibility-layer work, initially using Darling.

## Current Project Status

- **Phase 0 — Research & Baselines:** Active.
- **Task 001 — Xcode 16.4 x86_64 baseline:** Complete and validated on GitHub Actions.
- **Task 002 — Reproducible Darling baseline on Linux:** Next.

The validated Xcode 16.4 baseline confirms that the main Xcode executable is universal (`x86_64 arm64`) and provides a machine-readable inventory for later compatibility work. See [docs/xcode-16.4-baseline.md](docs/xcode-16.4-baseline.md).

## Legal Boundary & Disclaimer

- **No Proprietary Code or Binaries:** This repository does **not** host, commit, or redistribute Apple Xcode, Apple SDKs, Apple frameworks, Simulator runtimes, or extracted proprietary Apple binaries.
- **Non-Affiliation:** This project is independent and is **not** affiliated with, authorized, maintained, sponsored, or endorsed by Apple Inc.
- Apple, Xcode, macOS, Swift, and iOS are trademarks of Apple Inc.

## Architecture & Roadmap

- [Architecture](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)
- [Xcode 16.4 baseline](docs/xcode-16.4-baseline.md)
