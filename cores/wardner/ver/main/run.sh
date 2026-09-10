#!/usr/bin/env bash
# Boot bench for the Wardner main CPU.
#
#   ./run.sh <dir with the wardnerb ROM set> [sim ms] [extra +plusargs...]
#
# +snap=<ms>[,<ms>...] freezes the main CPU at each of those bench milliseconds
# in turn and dumps every video RAM into snap<ms>/, so one boot can leave
# several snapshots behind. The run ends after the last one.
#
# Builds the main Z80's program region and the DSP's mask ROM from the real
# set, runs the boot sequence with the DSP subsystem attached, and reports
# which milestones the game reaches. Everything it prints comes from the game's
# own behaviour - no reference model is involved at this level.
#
# Verilator is used rather than iverilog: the T80 is 21k lines and iverilog is
# roughly two orders of magnitude too slow to reach the end of the power-on
# tests.
set -u
cd "$(dirname "$0")"
ROMDIR=${1:-}
RUNMS=${2:-9000}
shift 2 2>/dev/null || true

if [ -z "$ROMDIR" ] || [ ! -f "$ROMDIR/82s137.1d" ]; then
    echo "usage: $0 <dir with the wardnerb ROM set> [sim ms] [+plusargs]" >&2
    exit 2
fi

# tb_main writes each snapshot into snap<ms>/, and Verilog cannot make a
# directory, so create one per +snap= target here.
for a in "$@"; do
    case "$a" in
        +snap=*) for ms in $(echo "${a#+snap=}" | tr ',' ' '); do mkdir -p "snap$ms"; done ;;
    esac
done

python3 mkrom.py "$ROMDIR" main.hex || exit 1
python3 ../dsp/dsp_from_proms.py "$ROMDIR" dsp_real.hex >/dev/null || exit 1

verilator --binary --timing -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT \
    -Wno-CASEINCOMPLETE -Wno-BLKSEQ --top-module tb_main -o vtb -j 16 \
    -CFLAGS "-O2 -march=native" \
    -y ../../../../modules/jtopl/hdl +libext+.v \
    tb_main.v probe.v ../../hdl/jtwardner_main.v ../../hdl/jtwardner_sound.v \
    ../../hdl/jttoaplan1_dsp.v \
    ../../../../modules/jt32010/hdl/jt32010.v \
    ../../../../modules/jtframe/hdl/ram/jtframe_dual_ram.v \
    ../../../../modules/jtframe/hdl/cpu/t80/T80s.v > verilator.log 2>&1 \
    || { echo "verilator build failed, see verilator.log" >&2; exit 1; }

# MAXIO caps the port-write log so a runaway boot cannot fill the disk. A long
# attract-mode run needs a bigger one than a boot does.
./obj_dir/vtb +maxio="${MAXIO:-200000}" +runms="$RUNMS" "$@"
echo
echo "port trace written to boot.log"
