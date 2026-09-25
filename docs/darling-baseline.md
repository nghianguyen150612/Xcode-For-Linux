# Darling Baseline (Task 002)

## Goal

Establish a reproducible x86_64 Linux baseline for the compatibility layer before any Apple developer-tool binary is introduced.

Task 002 intentionally does **not** run Xcode, Apple Clang, Apple Swift, `xcodebuild`, Apple frameworks, or any proprietary Apple payload.

## Pinned Upstream

- Repository: `https://github.com/darlinghq/darling.git`
- Commit: `60ba801decee7a00782f74f6be4c8ffb013f79ff`
- Components: `system`
- 32-bit target: disabled (`TARGET_i386=OFF`)
- CI host: `ubuntu-24.04`, x86_64

The parent Darling commit pins all referenced submodule revisions through the upstream repository's submodule metadata.

## Why `system` first?

Darling documents `system` as the minimal component set that includes the core runtime plus the shell and essential system daemons. That is sufficient to establish whether the loader, darlingserver/runtime, prefix initialization, launch environment, and basic Darwin userland operate before expanding the build surface for Xcode-specific work.

## Workflow

`.github/workflows/darling-baseline.yml` performs:

1. Linux/x86_64 host verification.
2. Exact pinned Darling checkout with recursive submodules and Git LFS.
3. Installation of build dependencies using Darling's own `debian/control`.
4. x86_64-only `system` component build.
5. Installation into the standard prefix.
6. Non-interactive runtime probes through `darling shell`:
   - `/usr/bin/uname -a`
   - `/usr/bin/sw_vers`
   - `/usr/bin/arch`
   - `/bin/echo task-002-darling-baseline-ok`
7. Metadata/log artifact upload.

## Results

**Pending first CI execution.**

Task 002 is not complete until the pinned source is built and the runtime smoke probes have been reviewed. If GitHub-hosted runner restrictions prevent runtime initialization, the exact failure and host limitation must be captured rather than treated as a Darling compatibility failure.

## Output

The workflow uploads `darling-baseline` containing host/source/build/runtime metadata and logs. It does not upload Xcode, Apple SDKs, Apple frameworks, Simulator runtimes, or other Apple proprietary payloads.
