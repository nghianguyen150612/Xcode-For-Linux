# Xcode 16.4 Baseline Inventory (`x86_64`)

## Target

- **Target App:** Xcode 16.4 (`/Applications/Xcode_16.4.app`)
- **Xcode Build:** `16F6`
- **Host Architecture:** Intel `x86_64` (`macos-15-intel` runner)
- **Validated Workflow Run:** GitHub Actions run `36074965821`
- **Validated Source Commit:** `2c399626ba3b2f6072496d7c17cbbf0190a05d81`
- **Selection Rationale:** Xcode 16.4 is the primary bootstrap target because it is a modern Xcode release that still ships a large set of `x86_64` or universal Mach-O components suitable for Intel Linux compatibility research.

---

## Method

The inventory process is automated via `.github/workflows/xcode-baseline.yml` and `scripts/inspect-xcode.sh`:

1. **Host & Xcode Verification**
   - Verifies `uname -m` is exactly `x86_64`.
   - Resolves `/Applications/Xcode_16.4.app` or scans `/Applications/Xcode*.app` for exactly version `16.4`.
   - Records host details (`uname -a`, `sw_vers`, `sysctl machdep.cpu.brand_string`).

2. **Main Executable Analysis (`Xcode.app/Contents/MacOS/Xcode`)**
   - Captures `file`, `lipo -archs`, `otool -L`, `otool -l`, `nm -u`, and `codesign -dvvv` output.
   - Requires an `x86_64` slice.

3. **Mach-O Binary & Bundle Scan**
   - Recursively walks the Xcode bundle.
   - Detects thin and fat Mach-O formats by magic number.
   - Emits tab-safe, one-record-per-line TSV inventories.
   - Records executables, dylibs, frameworks, XPC/helper bundles, and architecture distribution.

4. **Developer Tools Baseline**
   - Sets `DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer`.
   - Probes `xcodebuild`, SDK enumeration, `clang`, and `swiftc`.

---

## Validated Results

The final Task 001 validation run completed successfully on **2026-09-24 UTC**.

- **Host:** macOS `15.7.9` build `24G830`
- **Host CPU:** Intel Core i7-8700B @ 3.20 GHz
- **Host architecture:** `x86_64` / GitHub Actions `RUNNER_ARCH=X64`
- **Xcode:** `16.4`, build `16F6`
- **Main Xcode executable architectures:** `x86_64 arm64`
- **Total Mach-O binaries:** `1813`
  - `x86_64` only: `128`
  - `arm64` only: `77`
  - Universal `x86_64 + arm64`: `1289`
  - Other / multi-architecture combinations: `319`
  - Unknown: `0`
- **Executable records:** `565`
- **Dynamic-library records:** `1138`
- **Framework directory records:** `4482`
- **XPC / helper bundle records:** `74`
- **TSV structural validation:** all `1813` architecture records and all generated executable/dylib/XPC records have the expected field count; no malformed rows were found.

### Developer-tool probes

All required probes exited successfully:

- `xcodebuild -version` → Xcode `16.4`, build `16F6`
- `xcodebuild -showsdks` → includes iOS `18.5`, macOS `15.5`, tvOS `18.5`, watchOS `11.5`, visionOS `2.5`, and DriverKit `24.5`
- `xcrun --find clang` → Xcode default toolchain
- `xcrun --find swiftc` → Xcode default toolchain
- `clang --version` → Apple clang `17.0.0 (clang-1700.0.13.5)`, target `x86_64-apple-darwin24.6.0`
- `swiftc --version` → Apple Swift `6.1.2`, target `x86_64-apple-macosx15.0`

---

## Artifact Schema

The validated `xcode-16.4-baseline-inventory` artifact contains:

```
host.txt
xcode-version.txt
developer-tools.txt
architectures.tsv
architecture-summary.txt
executables.tsv
frameworks.txt
dylibs.tsv
xpc-services.tsv
xcode-main/
├── file.txt
├── lipo.txt
├── otool-dependencies.txt
├── otool-load-commands.txt
├── nm-undefined.txt
└── codesign.txt
```

---

## Limitations

- This baseline establishes reproducible static and native-macOS observations only.
- It does **not** prove that Xcode or the captured developer tools execute on Linux.
- The artifact records metadata and command output only; the repository does not redistribute Apple proprietary binaries, SDKs, frameworks, or Simulator runtimes.

---

## Task 001 Exit Criteria

Task 001 is complete because:

1. the baseline workflow ran on a real GitHub-hosted Intel macOS runner;
2. the final run succeeded end-to-end;
3. the generated artifact was inspected;
4. the measured results above were recorded;
5. generated TSV inventories were structurally validated.

## Next Step

Proceed to **Task 002: establish a reproducible Darling baseline on Linux**, pinned to an exact upstream Darling commit, with a clean build and minimal smoke-test evidence before attempting any Xcode-specific compatibility patches.
