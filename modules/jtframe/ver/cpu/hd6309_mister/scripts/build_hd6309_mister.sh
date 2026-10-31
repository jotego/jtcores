#!/usr/bin/env bash
set -euo pipefail

TARGET_INSTRUCTIONS=${TARGET_INSTRUCTIONS:-99999975}
NATIVE_MODE=${NATIVE_MODE:-1}
BUILD_DIR=${BUILD_DIR:-/nobackup/tasks/jtcores-147/hd6309_mister_build_$(date +%Y%m%d_%H%M%S)}
MISTER_TEMPLATE=${MISTER_TEMPLATE:-/nobackup/jtmisc/mister/Template_MiSTer}
JTROOT=${JTROOT:-/home/jtejada/jtcores-3}
QUARTUS_SH=${QUARTUS_SH:-/nobackup/opt/quartus_free/intelFPGA_lite/bin/quartus_sh}
PARALLEL_PROCESSORS=${PARALLEL_PROCESSORS:-4}
SKILL_DIR=${SKILL_DIR:-/home/jtejada/jtcores-skills/skills/mister-module-test}
if [[ ! "$TARGET_INSTRUCTIONS" =~ ^[0-9]+$ ]] || (( TARGET_INSTRUCTIONS < 25 || TARGET_INSTRUCTIONS > 99999975 || TARGET_INSTRUCTIONS % 25 != 0 )); then
    echo "TARGET_INSTRUCTIONS must be a positive multiple of 25 through 99999975 (32-bit E-cycle counter limit)" >&2
    exit 1
fi
if [[ ! "$NATIVE_MODE" =~ ^[01]$ ]]; then echo "NATIVE_MODE must be 0 (emulation) or 1 (native)" >&2; exit 1; fi
if [[ ! "$PARALLEL_PROCESSORS" =~ ^[0-9]+$ ]] || (( PARALLEL_PROCESSORS < 1 || PARALLEL_PROCESSORS > 16 )); then
    echo "PARALLEL_PROCESSORS must be between 1 and 16" >&2
    exit 1
fi
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TASK_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

if [[ ! -d "$MISTER_TEMPLATE" ]]; then
    echo "MiSTer template not found: $MISTER_TEMPLATE" >&2
    exit 1
fi
if [[ ! -f "$JTROOT/modules/jtframe/hdl/cpu/mc6809i.v" ]]; then
    echo "JTCORES source not found under JTROOT=$JTROOT" >&2
    exit 1
fi
if [[ ! -x "$QUARTUS_SH" ]]; then
    echo "quartus_sh not executable: $QUARTUS_SH" >&2
    exit 1
fi
if [[ -e "$BUILD_DIR" ]]; then
    echo "Build directory already exists; choose a new BUILD_DIR: $BUILD_DIR" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR"
cp -a "$MISTER_TEMPLATE/." "$BUILD_DIR/"
sed -i "s/^set_global_assignment -name NUM_PARALLEL_PROCESSORS .*/set_global_assignment -name NUM_PARALLEL_PROCESSORS $PARALLEL_PROCESSORS/" "$BUILD_DIR/Template.qsf"

# MiSTer Template supplies Quartus 17 PLL QIPs. Quartus 20.x requests
# pll_q20.qip, so alias its compatible generated PLL source list in this
# isolated build copy only.
if [[ ! -f "$BUILD_DIR/sys/pll_q20.qip" && -f "$BUILD_DIR/sys/pll_q17.qip" ]]; then
    cp "$BUILD_DIR/sys/pll_q17.qip" "$BUILD_DIR/sys/pll_q20.qip"
fi

mkdir -p "$BUILD_DIR/module_test_src"
cp "$SKILL_DIR/rtl/mister_test_transport.sv" "$BUILD_DIR/module_test_src/"
cp "$TASK_DIR/rtl/hd6309_cycle_test.sv" "$BUILD_DIR/module_test_src/"
cp "$TASK_DIR/rtl/emu.sv" "$BUILD_DIR/module_test_src/"
cp "$JTROOT/modules/jtframe/hdl/cpu/mc6809i.v" "$BUILD_DIR/module_test_src/"
cp "$JTROOT/modules/jtframe/hdl/cpu/jtframe_hd6309_arith.v" "$BUILD_DIR/module_test_src/"

cat > "$BUILD_DIR/files.qip" <<'QIP'
set_global_assignment -name QIP_FILE rtl/pll.qip
set_global_assignment -name SYSTEMVERILOG_FILE module_test_src/mister_test_transport.sv
set_global_assignment -name SYSTEMVERILOG_FILE module_test_src/hd6309_cycle_test.sv
set_global_assignment -name SYSTEMVERILOG_FILE module_test_src/emu.sv
set_global_assignment -name VERILOG_FILE module_test_src/mc6809i.v
set_global_assignment -name VERILOG_FILE module_test_src/jtframe_hd6309_arith.v
QIP
printf '\nset_global_assignment -name VERILOG_MACRO "MCTEST_TARGET_INSTRUCTIONS=%s"\n' "$TARGET_INSTRUCTIONS" >> "$BUILD_DIR/Template.qsf"
printf 'set_global_assignment -name VERILOG_MACRO "MCTEST_NATIVE_MODE=%s"\n' "$NATIVE_MODE" >> "$BUILD_DIR/Template.qsf"
printf 'set_global_assignment -name VERILOG_MACRO "MISTER_DEBUG_NOHDMI=1"\n' >> "$BUILD_DIR/Template.qsf"

(
    cd "$BUILD_DIR"
    sha256sum \
        module_test_src/mister_test_transport.sv \
        module_test_src/hd6309_cycle_test.sv \
        module_test_src/emu.sv \
        module_test_src/mc6809i.v \
        module_test_src/jtframe_hd6309_arith.v > source_manifest.sha256
    {
        echo "TARGET_INSTRUCTIONS=$TARGET_INSTRUCTIONS"
        echo "NATIVE_MODE=$NATIVE_MODE"
        echo "QUARTUS_SH=$QUARTUS_SH"
        echo "PARALLEL_PROCESSORS=$PARALLEL_PROCESSORS"
        echo "MISTER_TEMPLATE=$MISTER_TEMPLATE"
        echo "JTROOT=$JTROOT"
        echo "BUILD_DIR=$BUILD_DIR"
    } > build-summary.txt
    /usr/bin/time -p "$QUARTUS_SH" --flow compile Template > quartus.log 2>&1
    echo "RBF=$BUILD_DIR/output_files/Template.rbf" >> build-summary.txt
)

cat "$BUILD_DIR/build-summary.txt"
