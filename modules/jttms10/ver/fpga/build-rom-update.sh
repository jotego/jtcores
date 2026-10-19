#!/usr/bin/env bash
set -euo pipefail

main() {
    START_NS=$(python3 -c 'import time; print(time.monotonic_ns())')
    SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    parse_args "$@"
    validate_args
    generate_roms
    validate_rom_delta
    clone_fit
    stage_roms
    run_quartus_update
    make_variant_receipt
    print_summary
}

usage() {
    cat >&2 <<'EOF'
Usage: build-rom-update.sh --base-build DIR --source-root DIR \
  --hardware-source-root DIR --parent-receipt JSON --build-dir NEW_DIR \
  --evidence-dir DIR --variant NAME --overlay NAME --boot-id UUID

Copy a successful fitted QIP-bound build, regenerate the CPU source, update its
MIF with Quartus CDB, assemble an inherited-fit RBF, and write a ROM-update
receipt. The base build is read-only. Use a fresh build directory per variant.
EOF
    exit 2
}

parse_args() {
    while (($#)); do
        case "$1" in
            --base-build) BASE_BUILD=${2:?}; shift 2 ;;
            --source-root) SOURCE_ROOT=${2:?}; shift 2 ;;
            --hardware-source-root) HARDWARE_SOURCE_ROOT=${2:?}; shift 2 ;;
            --parent-receipt) PARENT_RECEIPT=${2:?}; shift 2 ;;
            --build-dir) BUILD_DIR=${2:?}; shift 2 ;;
            --evidence-dir) EVIDENCE_DIR=${2:?}; shift 2 ;;
            --variant) VARIANT=${2:?}; shift 2 ;;
            --overlay) OVERLAY=${2:?}; shift 2 ;;
            --boot-id) BOOT_ID=${2:?}; shift 2 ;;
            --help|-h) usage ;;
            *) echo "Unknown argument: $1" >&2; usage ;;
        esac
    done
}

validate_args() {
    local var
    for var in BASE_BUILD SOURCE_ROOT HARDWARE_SOURCE_ROOT PARENT_RECEIPT BUILD_DIR EVIDENCE_DIR VARIANT OVERLAY BOOT_ID; do
        [[ -n ${!var:-} ]] || { echo "Missing required argument: --${var,,}" >&2; usage; }
    done
    BASE_BUILD=$(realpath -e -- "$BASE_BUILD")
    SOURCE_ROOT=$(realpath -e -- "$SOURCE_ROOT")
    HARDWARE_SOURCE_ROOT=$(realpath -e -- "$HARDWARE_SOURCE_ROOT")
    PARENT_RECEIPT=$(realpath -e -- "$PARENT_RECEIPT")
    BUILD_DIR=$(realpath -m -- "$BUILD_DIR")
    EVIDENCE_DIR=$(realpath -m -- "$EVIDENCE_DIR")
    [[ ! -e $BUILD_DIR ]] || { echo "Build clone already exists: $BUILD_DIR" >&2; exit 1; }
    python3 - "$BASE_BUILD" "$BUILD_DIR" "$EVIDENCE_DIR" <<'PY'
import sys
from pathlib import Path
base, build, evidence = (Path(p).resolve() for p in sys.argv[1:])
def overlaps(a, b):
    return a == b or a in b.parents or b in a.parents
if overlaps(base, build):
    raise SystemExit('build clone must be outside and separate from the immutable base build')
if overlaps(base, evidence):
    raise SystemExit('evidence directory must be outside and separate from the immutable base build')
if overlaps(build, evidence):
    raise SystemExit('build clone and evidence directory must not overlap')
PY
    [[ $VARIANT =~ ^[A-Za-z0-9_.-]+$ && $OVERLAY =~ ^[A-Za-z0-9_.-]+$ ]] || {
        echo 'Variant and overlay must be simple unique names' >&2; exit 1;
    }
    [[ $BOOT_ID =~ ^[0-9a-fA-F-]{36}$ ]] || { echo 'Invalid board boot ID' >&2; exit 1; }
    [[ -s $BASE_BUILD/output_files/test_board.rbf && -s $BASE_BUILD/v2-build-inputs.json &&
       -s $BASE_BUILD/v2-build-result.json && -s $BASE_BUILD/output_files/test_board.sta.summary ]] || {
        echo 'Base build lacks a successful incremental full-fit checkpoint' >&2; exit 1;
    }
    [[ -x $HARDWARE_SOURCE_ROOT/modules/jttms10/ver/build.sh ]] || {
        echo 'Hardware checkout lacks the CPU source generator' >&2; exit 1;
    }
    mkdir -p -- "$EVIDENCE_DIR"
    EVIDENCE_DIR=$(realpath -e -- "$EVIDENCE_DIR")
    mkdir -p -- "$(dirname -- "$BUILD_DIR")"
    GEN_DIR=$EVIDENCE_DIR/generated
    LOG_DIR=$EVIDENCE_DIR/logs
    mkdir -p -- "$LOG_DIR"
}

generate_roms() {
    [[ ! -e $GEN_DIR ]] || { echo "Generated ROM path already exists: $GEN_DIR" >&2; exit 1; }
    mkdir -p -- "$GEN_DIR"
    PHASE_CWD=$GEN_DIR
    run_phase source-generation "$EVIDENCE_DIR/source-generation.log" \
        "$EVIDENCE_DIR/source-generation.time" \
        bash "$HARDWARE_SOURCE_ROOT/modules/jttms10/ver/build.sh" "$GEN_DIR"
    unset PHASE_CWD
}

validate_rom_delta() {
    python3 - "$SCRIPT_DIR" "$SOURCE_ROOT" "$HARDWARE_SOURCE_ROOT" "$PARENT_RECEIPT" "$GEN_DIR" "$BASE_BUILD" <<'PY'
import json, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from write_programming_receipt import (artifact_hashes, cpu_source_fingerprints,
                                       sha256,
                                       parse_mif,
                                       cpu_source_fingerprint_digest)
baseline, variant = Path(sys.argv[2]), Path(sys.argv[3])
parent = json.loads(Path(sys.argv[4]).read_text())
generated, base_build = Path(sys.argv[5]), Path(sys.argv[6])
base_fp = cpu_source_fingerprints(baseline)
variant_fp = cpu_source_fingerprints(variant)
if parent.get('cpu_source_fingerprints') != base_fp or parent.get('cpu_source_fingerprint_sha256') != cpu_source_fingerprint_digest(base_fp):
    raise SystemExit('parent receipt is not bound to the selected baseline source')
changed = sorted(p for p in set(base_fp) | set(variant_fp) if base_fp.get(p) != variant_fp.get(p))
if changed != ['modules/jttms10/ucode/tms10.yaml']:
    raise SystemExit(f'ROM experiment must change only main-control microcode YAML; found {changed}')
base_generated = {p: h for p, h in parent.get('current_source_generated_files', {}).items()
                  if Path(p).suffix in {'.uc', '.vh', '.hex'}}
new_generated = artifact_hashes(generated)
delta = sorted(p for p in set(base_generated) | set(new_generated)
               if base_generated.get(p) != new_generated.get(p))
if delta != ['tms10.uc']:
    raise SystemExit(f'main-control ROM experiment changed unexpected generated files: {delta}')
base_all = parent.get('current_source_generated_files', {})
variant_all = {p.name: sha256(p) for p in generated.iterdir() if p.is_file()}
all_delta = sorted(p for p in set(base_all) | set(variant_all)
                   if base_all.get(p) != variant_all.get(p))
if 'tms10.uc' not in all_delta or set(all_delta) - {'tms10.uc', 'tms10.lst'}:
    raise SystemExit(f'main-control source generation changed unexpected outputs: {all_delta}')
base_uc = base_build / 'jttms10-generated/tms10.uc'
if not base_uc.is_file():
    raise SystemExit('baseline generated main-control ROM is missing')
width, base_mif = parse_mif(base_build / 'db/test_board.ram0_jttms10_ctrl_cc30e43c.hdl.mif')
if width != 62 or base_mif != base_uc.read_text().splitlines():
    raise SystemExit('parent fitted main-control MIF does not match baseline generated tms10.uc')
print('source delta: modules/jttms10/ucode/tms10.yaml')
print('generated delta: tms10.uc')
PY
}

clone_fit() {
    [[ ! -e $BUILD_DIR ]] || { echo "Build clone already exists: $BUILD_DIR" >&2; exit 1; }
    PHASE_CWD=$PWD
    run_phase clone-fit "$EVIDENCE_DIR/clone-fit.log" "$EVIDENCE_DIR/clone-fit.time" \
        cp -a -- "$BASE_BUILD" "$BUILD_DIR"
    unset PHASE_CWD
    printf '%s\n' "$BASE_BUILD" > "$EVIDENCE_DIR/base-build-path.txt"
}

stage_roms() {
    local package="$BUILD_DIR/ip/jttms10_fpga_runner"
    mkdir -p -- "$BUILD_DIR/jttms10-generated" "$package"
    cp -f -- "$GEN_DIR/tms10.uc" "$BUILD_DIR/tms10.uc"
    cp -f -- "$GEN_DIR/tms10.uc" "$package/tms10.uc"
    cp -f -- "$GEN_DIR/tms10.uc" "$BUILD_DIR/jttms10-generated/tms10.uc"
    python3 - "$SCRIPT_DIR" "$BUILD_DIR/db/test_board.ram0_jttms10_ctrl_cc30e43c.hdl.mif" "$GEN_DIR/tms10.uc" <<'PY'
import re, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from write_programming_receipt import parse_mif
mif_path, uc_path = Path(sys.argv[2]), Path(sys.argv[3])
old_text = mif_path.read_text()
width, old_words = parse_mif(mif_path)
new_words = uc_path.read_text().splitlines()
if width != 62 or len(old_words) != 4096 or len(new_words) != 4096 or any(
        len(word) != width or set(word) - {'0', '1'} for word in new_words):
    raise SystemExit('MIF/ROM dimensions or binary data differ from the fitted main-control ROM')
match = re.match(r'(?s)^(.*?CONTENT BEGIN\s*\n).*?(\nEND;\s*)$', old_text)
if not match:
    raise SystemExit('could not preserve the fitted MIF framing while updating contents')
body = ''.join(f'\t{address} :\t{new_words[address]};\n' for address in range(4095, -1, -1))
mif_path.write_text(match.group(1) + body + match.group(2))
round_width, round_words = parse_mif(mif_path)
if round_width != width or round_words != new_words:
    raise SystemExit('updated main-control MIF failed exact round-trip validation')
print(f'updated MIF: {mif_path} ({len(new_words)} x {width} bits)')
PY
}

run_quartus_update() {
    run_phase quartus-cdb "$LOG_DIR/cdb.log" "$LOG_DIR/cdb.time" \
        /opt/quartus_free/quartus_cdb test_board -c test_board --update_mif
    run_phase quartus-asm "$LOG_DIR/asm.log" "$LOG_DIR/asm.time" \
        /opt/quartus_free/quartus_asm test_board -c test_board \
        --read_settings_files=off --write_settings_files=off
}

run_phase() {
    local name=$1 log=$2 timing=$3; shift 3
    local status cwd=${PHASE_CWD:-$BUILD_DIR}
    echo "Running $name in $BUILD_DIR"
    set +e
    (cd -- "$cwd" && /usr/bin/time -f 'seconds=%e\nexit=%x' -o "$timing" "$@") >"$log" 2>&1
    status=$?
    set -e
    if ((status != 0)); then
        echo "${name} failed with status ${status}; log: ${log}" >&2
        return "$status"
    fi
}

make_variant_receipt() {
    local rbf="$BUILD_DIR/output_files/test_board.rbf"
    local image_sha firmware image
    image_sha=$(sha256sum "$rbf" | awk '{print $1}')
    firmware="jtcores-rom-${VARIANT}-${image_sha:0:12}.rbf"
    image="$EVIDENCE_DIR/$firmware"
    cp -f -- "$rbf" "$image"
    python3 "$SCRIPT_DIR/write_programming_receipt.py" \
        --image "$image" --build-dir "$BUILD_DIR" --base-build-dir "$BASE_BUILD" \
        --source-root "$SOURCE_ROOT" --hardware-source-root "$HARDWARE_SOURCE_ROOT" \
        --rom-update-parent-receipt "$PARENT_RECEIPT" --variant-name "$VARIANT" \
        --cdb-log "$LOG_DIR/cdb.log" --asm-log "$LOG_DIR/asm.log" \
        --cdb-time "$LOG_DIR/cdb.time" --asm-time "$LOG_DIR/asm.time" \
        --source-generation-time "$EVIDENCE_DIR/source-generation.time" \
        --boot-id "$BOOT_ID" --overlay "$OVERLAY" \
        --output "$EVIDENCE_DIR/rom-update-receipt.json"
}

print_summary() {
    local end_ns total
    end_ns=$(python3 -c 'import time; print(time.monotonic_ns())')
    total=$(python3 - "$START_NS" "$end_ns" <<'PY'
import sys
print(f'{(int(sys.argv[2])-int(sys.argv[1]))/1e9:.6f}')
PY
)
    printf '%s\n' "$total" > "$EVIDENCE_DIR/host-total-seconds.txt"
    sha256sum "$EVIDENCE_DIR/rom-update-receipt.json" \
        "$EVIDENCE_DIR/"jtcores-rom-"$VARIANT"-*.rbf
    printf 'Source generation: '; cat "$EVIDENCE_DIR/source-generation.time"
    printf 'Fit clone: '; cat "$EVIDENCE_DIR/clone-fit.time"
    printf 'CDB: '; cat "$LOG_DIR/cdb.time"
    printf 'ASM: '; cat "$LOG_DIR/asm.time"
    printf 'Full helper wall: %s seconds\n' "$total"
    printf 'Build clone: %s\nEvidence: %s\n' "$BUILD_DIR" "$EVIDENCE_DIR"
}

main "$@"
