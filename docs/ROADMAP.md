# Project Roadmap

The development and research phases for `Xcode-For-Linux` are structured as follows.

## Phase 0: Research & Baselines

- [x] **Task 001:** Establish and validate the Xcode 16.4 `x86_64` baseline inventory on an Intel macOS host.
- [x] Inventory Mach-O structure, direct dependencies, frameworks, dylibs, XPC/helper bundles, and native CLI entry points.
- [x] **Task 002:** Establish a reproducible, pinned Darling baseline environment on x86_64 Linux.
  - BUILD BASELINE: PASS
  - RUNTIME BASELINE: BLOCKED BY GitHub-hosted runner kernel namespace / overlayfs restrictions (documented in `docs/darling-baseline.md`).

## Phase 1: Apple Developer CLI Tools Through Compatibility Layer

- [ ] **Task 003:** Test basic Apple CLI binaries such as `clang`, `swiftc`, and relevant toolchain libraries under Darling.
- [ ] Map missing dynamic libraries, system calls, framework APIs, and runtime behavior.

## Phase 2: `xcodebuild` and Build-System Compatibility

- [ ] Investigate `xcodebuild` dependencies and execution prerequisites.
- [ ] Enable headless command-line project building on Linux.

## Phase 3: Xcode.app Startup and GUI

- [ ] Investigate Cocoa/AppKit/DVT framework compatibility under Darling's GUI layer.
- [ ] Execute the main `Xcode` executable and iteratively address initialization/runtime failures.

## Phase 4: Physical Apple Device Tooling

- [ ] Investigate device discovery, installation, launch, and debugging paths.
- [ ] Integrate or bridge compatible USB/network device services where appropriate.

## Phase 5: CoreSimulator / Simulator Runtimes

- [ ] Map CoreSimulator service/runtime dependencies.
- [ ] Investigate simulator runtime loading, boot, graphics, app installation, and debugging prerequisites on Linux.
