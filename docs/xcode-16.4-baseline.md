# Xcode 16.4 Baseline Inventory (`x86_64`)

## Target

- **Target App:** Xcode 16.4 (`/Applications/Xcode_16.4.app`)
- **Host Architecture:** Intel `x86_64` (macOS 15 runner)
- **Selection Rationale:** Xcode 16.4 is the primary target for bootstrap investigation because it represents a modern Xcode release supporting current Apple SDKs while still shipping universal `x86_64` binaries suitable for Intel Linux emulation targets.

---

## Method

The inventory process is automated via `.github/workflows/xcode-baseline.yml` and `scripts/inspect-xcode.sh`:

1. **Host & Xcode Verification:**
   - Verifies `uname -m` is `x86_64`.
   - Resolves `/Applications/Xcode_16.4.app` or scans `/Applications/Xcode*.app` for version `16.4`.
   - Records host details (`uname -a`, `sw_vers`, `sysctl machdep.cpu.brand_string`).

2. **Main Executable Analysis (`Xcode.app/Contents/MacOS/Xcode`):**
   - Captures `file`, `lipo -archs`, `otool -L`, `otool -l`, `nm -u`, and `codesign -dvvv` outputs into `artifacts/xcode-16.4/xcode-main/`.
   - Confirms presence of `x86_64` slice; aborts workflow if missing.

3. **Mach-O Binary & Bundle Scan:**
   - Recursively walks the bundle to discover all Mach-O binaries.
   - Categorizes architectures into `architectures.tsv` and generates `architecture-summary.txt`.
   - Extracts lists for executables (`executables.tsv`), dynamic libraries (`dylibs.tsv`), frameworks (`frameworks.txt`), and XPC services/helpers (`xpc-services.tsv`).

4. **Developer Tools Baseline:**
   - Sets `DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer`.
   - Probes `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun --find clang`, `xcrun --find swiftc`, `clang --version`, and `swiftc --version`.

---

## Results & Findings

> *Note: Below findings are captured upon running `.github/workflows/xcode-baseline.yml` on an Intel `x86_64` macOS runner.*

- **Host Architecture:** `x86_64` (macOS 15 GitHub Actions hosted runner)
- **Xcode Version / Build:** `16.4` (Build details captured in `xcode-version.txt`)
- **Main Executable Architectures:** Universal binary (`x86_64 arm64`) containing a valid `x86_64` slice.
- **Mach-O Binaries & Architecture Distribution:**
  - Machine-readable breakdown in `architectures.tsv` and `architecture-summary.txt`.
- **Framework & Dynamic Library Counts:**
  - Framework inventory recorded in `frameworks.txt`.
  - Dylib inventory recorded in `dylibs.tsv`.
- **XPC Services & Helper Apps:**
  - Bundle IDs and executable paths documented in `xpc-services.tsv`.
- **CLI Tool Probes:**
  - `xcodebuild`, `xcrun`, `clang`, and `swiftc` responses documented in `developer-tools.txt`.

---

## Limitations

- This inventory verifies binary architectures and static dependencies on macOS.
- **Does not prove execution on Linux:** Satisfying static dependencies is a prerequisite, but dynamic runtime behavior under Darling/Linux requires further compatibility layer research.

---

## Next Steps

1. Establish a reproducible Darling compatibility baseline on Linux.
2. Probe Apple developer CLI tools (`clang`, `swiftc`, `libLTO.dylib`) under Darling.
3. Map missing system dynamic libraries, Cocoa/AppKit symbols, and kernel interface requirements.
