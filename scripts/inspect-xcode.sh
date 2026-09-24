#!/usr/bin/env bash
set -euo pipefail

# Xcode inspection script for macOS Intel (x86_64) baseline
# Usage: ./scripts/inspect-xcode.sh [xcode_app_path] [output_dir]

XCODE_REQ_PATH="${1:-/Applications/Xcode_16.4.app}"
OUTPUT_DIR="${2:-artifacts/xcode-16.4}"

echo "=== Starting Xcode Inspection ==="
echo "Requested Xcode Path: ${XCODE_REQ_PATH}"
echo "Output Directory:     ${OUTPUT_DIR}"

# 1. Locate Xcode 16.4
RESOLVED_XCODE=""

if [[ -d "${XCODE_REQ_PATH}" ]]; then
    RESOLVED_XCODE="${XCODE_REQ_PATH}"
else
    echo "Path '${XCODE_REQ_PATH}' not found directly. Searching /Applications/Xcode*.app..."
    for app in /Applications/Xcode*.app; do
        if [[ -d "${app}" ]]; then
            ver=""
            if [[ -f "${app}/Contents/Info.plist" ]]; then
                ver=$(defaults read "${app}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || true)
            fi
            if [[ "${ver}" == "16.4" ]]; then
                RESOLVED_XCODE="${app}"
                echo "Found Xcode 16.4 candidate: ${RESOLVED_XCODE}"
                break
            fi
        fi
    done
fi

if [[ -z "${RESOLVED_XCODE}" || ! -d "${RESOLVED_XCODE}" ]]; then
    echo "ERROR: Xcode 16.4 could not be located at '${XCODE_REQ_PATH}' or under /Applications/Xcode*.app" >&2
    exit 1
fi

# Verify version of resolved Xcode
XCODE_VER=$(defaults read "${RESOLVED_XCODE}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || true)
XCODE_BUILD=$(DEVELOPER_DIR="${RESOLVED_XCODE}/Contents/Developer" xcodebuild -version 2>/dev/null \
    | awk '/^Build version / { print $3; exit }')

if [[ -z "${XCODE_BUILD}" ]]; then
    XCODE_BUILD=$(defaults read "${RESOLVED_XCODE}/Contents/Info.plist" DTXcodeBuild 2>/dev/null || true)
fi

echo "Resolved Xcode Path:  ${RESOLVED_XCODE}"
echo "Xcode Version:        ${XCODE_VER:-Unknown}"
echo "Xcode Build:          ${XCODE_BUILD:-Unknown}"

if [[ "${XCODE_VER}" != "16.4" ]]; then
    echo "ERROR: Located Xcode version is '${XCODE_VER:-Unknown}', expected exactly 16.4" >&2
    exit 1
fi

if [[ -z "${XCODE_BUILD}" ]]; then
    echo "ERROR: Could not determine the Xcode build number." >&2
    exit 1
fi

mkdir -p "${OUTPUT_DIR}" "${OUTPUT_DIR}/xcode-main"

# Record version info
cat << EOF > "${OUTPUT_DIR}/xcode-version.txt"
Xcode Path:  ${RESOLVED_XCODE}
Version:     ${XCODE_VER}
Build:       ${XCODE_BUILD}
EOF

# 2. Inspect Main Executable
XCODE_MAIN="${RESOLVED_XCODE}/Contents/MacOS/Xcode"
XCODE_MAIN_DIR="${OUTPUT_DIR}/xcode-main"

if [[ ! -f "${XCODE_MAIN}" ]]; then
    echo "ERROR: Xcode main executable not found at ${XCODE_MAIN}" >&2
    exit 1
fi

echo "=== Inspecting Main Executable ==="
file "${XCODE_MAIN}" > "${XCODE_MAIN_DIR}/file.txt" 2>&1
lipo -archs "${XCODE_MAIN}" > "${XCODE_MAIN_DIR}/lipo.txt" 2>&1
otool -L "${XCODE_MAIN}" > "${XCODE_MAIN_DIR}/otool-dependencies.txt" 2>&1
otool -l "${XCODE_MAIN}" > "${XCODE_MAIN_DIR}/otool-load-commands.txt" 2>&1
nm -u "${XCODE_MAIN}" > "${XCODE_MAIN_DIR}/nm-undefined.txt" 2>&1
codesign -dvvv "${XCODE_MAIN}" > "${XCODE_MAIN_DIR}/codesign.txt" 2>&1

MAIN_ARCHS=$(cat "${XCODE_MAIN_DIR}/lipo.txt")
echo "Main Executable Architectures: ${MAIN_ARCHS}"

if [[ "${MAIN_ARCHS}" != *"x86_64"* ]]; then
    echo "ERROR: Main Xcode executable does NOT contain x86_64 architecture!" >&2
    exit 1
fi

# 3. Inventory Mach-O binaries, frameworks, dylibs, XPC services
echo "=== Scanning Xcode Bundle for Mach-O binaries & services ==="

ARCH_TSV="${OUTPUT_DIR}/architectures.tsv"
EXEC_TSV="${OUTPUT_DIR}/executables.tsv"
DYLIBS_TSV="${OUTPUT_DIR}/dylibs.tsv"
FRAMEWORKS_TXT="${OUTPUT_DIR}/frameworks.txt"
XPC_TSV="${OUTPUT_DIR}/xpc-services.tsv"

printf "relative_path\tkind\tarchitectures\n" > "${ARCH_TSV}"
printf "relative_path\tarchitectures\tmach_o_type\n" > "${EXEC_TSV}"
printf "relative_path\tarchitectures\n" > "${DYLIBS_TSV}"
printf "bundle_path\tbundle_id\texecutable\tarchitectures\n" > "${XPC_TSV}"

# Use python3 to perform fast and deterministic inspection of files under RESOLVED_XCODE
python3 - "${RESOLVED_XCODE}" "${OUTPUT_DIR}" << 'PYEOF'
import sys
import os
import subprocess
import plistlib

xcode_path = os.path.abspath(sys.argv[1])
output_dir = sys.argv[2]

arch_tsv_path = os.path.join(output_dir, "architectures.tsv")
exec_tsv_path = os.path.join(output_dir, "executables.tsv")
dylibs_tsv_path = os.path.join(output_dir, "dylibs.tsv")
frameworks_txt_path = os.path.join(output_dir, "frameworks.txt")
xpc_tsv_path = os.path.join(output_dir, "xpc-services.tsv")
summary_txt_path = os.path.join(output_dir, "architecture-summary.txt")

macho_records = []
exec_records = []
dylib_records = []
framework_paths = set()
xpc_records = []

x86_64_only = 0
arm64_only = 0
universal_x86_arm = 0
other_arch_count = 0
unknown_count = 0

for root, dirs, files in os.walk(xcode_path):
    # Detect .framework directories
    for d in dirs:
        if d.endswith(".framework"):
            full_fw_path = os.path.join(root, d)
            rel_fw_path = os.path.relpath(full_fw_path, xcode_path)
            framework_paths.add((rel_fw_path, d))

    for f in files:
        full_path = os.path.join(root, f)
        if os.path.islink(full_path):
            continue

        # Check if file is Mach-O using magic numbers or lipo
        try:
            with open(full_path, "rb") as fp:
                magic = fp.read(4)
        except Exception:
            continue

        # Mach-O magic numbers (32-bit, 64-bit, 32-bit fat, 64-bit fat, and byte swaps):
        # MH_MAGIC        = 0xfeedface  (b'\xfe\xed\xfa\xce')
        # MH_CIGAM        = 0xcefaedfe  (b'\xce\xfa\xed\xfe')
        # MH_MAGIC_64     = 0xfeedfacf  (b'\xfe\xed\xfa\xcf')
        # MH_CIGAM_64     = 0xcffaedfe  (b'\xcf\xfa\xed\xfe')
        # FAT_MAGIC       = 0xcafebabe  (b'\xca\xfe\xba\xbe')
        # FAT_CIGAM       = 0xbebafeca  (b'\xbe\xba\xfe\xca')
        # FAT_MAGIC_64    = 0xcafebabf  (b'\xca\xfe\xba\xbf')
        # FAT_CIGAM_64    = 0xbfbafeca  (b'\xbf\xba\xfe\xca')
        is_macho = magic in (
            b'\xfe\xed\xfa\xce', b'\xce\xfa\xed\xfe',
            b'\xfe\xed\xfa\xcf', b'\xcf\xfa\xed\xfe',
            b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca',
            b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca'
        )

        if not is_macho:
            continue

        rel_path = os.path.relpath(full_path, xcode_path)

        # Get file command output for kind
        try:
            raw_file_out = subprocess.check_output(["file", "-b", full_path], text=True).strip()
            # Universal Mach-O descriptions can span multiple lines. Keep TSV records
            # one-line and tab-safe while preserving the full observable description.
            file_out = " | ".join(
                line.strip().expandtabs(1)
                for line in raw_file_out.splitlines()
                if line.strip()
            )
        except Exception:
            file_out = "Mach-O binary"

        # Get lipo archs
        try:
            lipo_out = subprocess.check_output(["lipo", "-archs", full_path], text=True).strip()
        except Exception:
            lipo_out = "unknown"

        archs = " ".join(sorted(lipo_out.split())) if lipo_out else "unknown"

        macho_records.append((rel_path, file_out, archs))

        # Categorize architectures
        arch_set = set(archs.split())
        if arch_set == {"x86_64"}:
            x86_64_only += 1
        elif arch_set == {"arm64"}:
            arm64_only += 1
        elif arch_set == {"x86_64", "arm64"}:
            universal_x86_arm += 1
        elif archs == "unknown":
            unknown_count += 1
        else:
            other_arch_count += 1

        # Check if executable / bundle executable
        kind_lower = file_out.lower()
        if "executable" in kind_lower or "bundle" in kind_lower:
            mach_o_type = "executable"
            if "dynamically linked shared library" in kind_lower:
                mach_o_type = "dylib"
            elif "bundle" in kind_lower:
                mach_o_type = "bundle"
            exec_records.append((rel_path, archs, file_out))

        # Check if dylib
        if f.endswith(".dylib") or "dynamically linked shared library" in kind_lower:
            dylib_records.append((rel_path, archs))

# Find XPC services, appex, and helper bundles
for root, dirs, files in os.walk(xcode_path):
    for d in dirs:
        if d.endswith(".xpc") or d.endswith(".appex") or "helper" in d.lower():
            bundle_dir = os.path.join(root, d)
            rel_bundle = os.path.relpath(bundle_dir, xcode_path)
            info_plist = os.path.join(bundle_dir, "Contents", "Info.plist")
            if not os.path.exists(info_plist):
                info_plist = os.path.join(bundle_dir, "Info.plist")

            bundle_id = "unknown"
            exec_name = "unknown"
            archs = "unknown"

            if os.path.exists(info_plist):
                try:
                    with open(info_plist, "rb") as fp:
                        plist_data = plistlib.load(fp)
                        bundle_id = plist_data.get("CFBundleIdentifier", "unknown")
                        exec_name = plist_data.get("CFBundleExecutable", "unknown")
                except Exception:
                    pass

            if exec_name != "unknown":
                exec_full = os.path.join(bundle_dir, "Contents", "MacOS", exec_name)
                if not os.path.exists(exec_full):
                    exec_full = os.path.join(bundle_dir, exec_name)
                if os.path.exists(exec_full):
                    try:
                        lipo_out = subprocess.check_output(["lipo", "-archs", exec_full], text=True).strip()
                        archs = " ".join(sorted(lipo_out.split()))
                    except Exception:
                        pass

            xpc_records.append((rel_bundle, bundle_id, exec_name, archs))

# Sort records deterministically
macho_records.sort(key=lambda x: x[0])
exec_records.sort(key=lambda x: x[0])
dylib_records.sort(key=lambda x: x[0])
xpc_records.sort(key=lambda x: x[0])

# Write architectures.tsv
with open(arch_tsv_path, "a") as fp:
    for rel_path, kind, archs in macho_records:
        fp.write(f"{rel_path}\t{kind}\t{archs}\n")

# Write executables.tsv
with open(exec_tsv_path, "a") as fp:
    for rel_path, archs, kind in exec_records:
        fp.write(f"{rel_path}\t{archs}\t{kind}\n")

# Write dylibs.tsv
with open(dylibs_tsv_path, "a") as fp:
    for rel_path, archs in dylib_records:
        fp.write(f"{rel_path}\t{archs}\n")

# Write frameworks.txt
sorted_fw = sorted(list(framework_paths), key=lambda x: x[0])
with open(frameworks_txt_path, "w") as fp:
    fp.write("# Bundled Frameworks in Xcode\n\n")
    for rel_path, fw_name in sorted_fw:
        category = "other bundled framework"
        if "SharedFrameworks" in rel_path or "PrivateFrameworks" in rel_path or "PlugIns" in rel_path or "DVT" in fw_name or "IDE" in fw_name:
            category = "Xcode/DVT/IDE private framework"
        elif "Frameworks" in rel_path:
            category = "public-looking framework"
        fp.write(f"{rel_path} [{category}]\n")

# Write xpc-services.tsv
with open(xpc_tsv_path, "a") as fp:
    for rel_bundle, bundle_id, exec_name, archs in xpc_records:
        fp.write(f"{rel_bundle}\t{bundle_id}\t{exec_name}\t{archs}\n")

# Write architecture-summary.txt
with open(summary_txt_path, "w") as fp:
    fp.write(f"Total Mach-O Binaries:      {len(macho_records)}\n")
    fp.write(f"x86_64 only:                {x86_64_only}\n")
    fp.write(f"arm64 only:                 {arm64_only}\n")
    fp.write(f"Universal (x86_64 + arm64): {universal_x86_arm}\n")
    fp.write(f"Other / Multiple archs:     {other_arch_count}\n")
    fp.write(f"Unknown:                    {unknown_count}\n")

PYEOF

# 4. Probe Developer Tools
echo "=== Probing Developer Tools ==="
DEV_TOOLS_TXT="${OUTPUT_DIR}/developer-tools.txt"
export DEVELOPER_DIR="${RESOLVED_XCODE}/Contents/Developer"

echo "DEVELOPER_DIR=${DEVELOPER_DIR}" > "${DEV_TOOLS_TXT}"
echo "" >> "${DEV_TOOLS_TXT}"

probe_cmd() {
    local cmd_name="$1"
    shift
    echo "--- Command: ${cmd_name} ---" >> "${DEV_TOOLS_TXT}"
    set +e
    "$@" >> "${DEV_TOOLS_TXT}" 2>&1
    local status=$?
    set -e
    echo "[Exit Code: ${status}]" >> "${DEV_TOOLS_TXT}"
    echo "" >> "${DEV_TOOLS_TXT}"
}

probe_cmd "xcodebuild -version" xcodebuild -version
probe_cmd "xcodebuild -showsdks" xcodebuild -showsdks
probe_cmd "xcrun --find clang" xcrun --find clang
probe_cmd "xcrun --find swiftc" xcrun --find swiftc
probe_cmd "clang --version" xcrun clang --version
probe_cmd "swiftc --version" xcrun swiftc --version

echo "=== Xcode Inspection Complete ==="
