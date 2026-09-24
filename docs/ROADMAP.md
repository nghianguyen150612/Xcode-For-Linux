# Project Roadmap

The development and research phases for `Xcode-For-Linux` are structured as follows:

## Phase 0: Research & Baselines
- Establish `x86_64` baseline inventory for Xcode 16.4 on macOS host (Task 001).
- Analyze Mach-O structure, dependencies (`otool -L`), frameworks, dylibs, XPC services, and CLI entry points.
- Establish Darling baseline environment on Linux.

## Phase 1: Apple Developer CLI Tools Through Compatibility Layer
- Test basic CLI binaries (`clang`, `swiftc`, `libLTO.dylib`) under Darling.
- Map missing dynamic libraries, system calls, and framework dependencies.

## Phase 2: `xcodebuild` and Build-System Compatibility
- Investigate `xcodebuild` dependencies and execution prerequisites.
- Enable headless command-line project building on Linux.

## Phase 3: Xcode.app Startup and GUI
- Investigate Cocoa / AppKit / DVT framework compatibility under Darling GUI layer.
- Execute main `Xcode` executable and address initialization/runtime crashes.

## Phase 4: Physical Apple Device Tooling
- Support USB / network device communication services (`usbmuxd`, `mobiledevice`).

## Phase 5: CoreSimulator / Simulator Runtimes
- Investigate simulator runtime loading and execution prerequisites on Linux.
