#!/usr/bin/env bash
# Conformance test against the real Wardner DSP program.
#
# The program is not in this repository. Point this at a directory holding the
# wardnerb ROM set - the eight nibble PROMs 82s137.1d/1e/3d/3e and
# 82s131.3b/3a/2a/1a - and it will rebuild the DSP's mask ROM from them.
#
#   ./run_real.sh /path/to/wardnerb [seeds] [instructions]
#
# Two comparisons are run against the C reference model, both with the run bit
# held so the DSP free-runs:
#   * instruction level - PC and every register, one line per instruction
#   * transaction level - the host-visible events
# The host RAM contents are varied by seed, because the real code dispatches on
# a command block the Z80 would have left there.
set -u
cd "$(dirname "$0")"
ROMDIR=${1:-}
SEEDS=${2:-16}
INSNS=${3:-30000}
IKA=../../../../modules/ika32010/hdl

if [ -z "$ROMDIR" ] || [ ! -f "$ROMDIR/82s137.1d" ]; then
    echo "usage: $0 <dir with the wardnerb PROMs> [seeds] [instructions]" >&2
    echo "       (needs 82s137.1d/1e/3d/3e and 82s131.3b/3a/2a/1a)" >&2
    exit 2
fi

python3 dsp_from_proms.py "$ROMDIR" dsp_real.hex dsp_real.bin || exit 1
gcc -O2 -o ref32010 ref32010.c || exit 1
iverilog -g2012 -I"$IKA" -o tb.out tb_dsp.v ../../hdl/jttoaplan1_dsp.v \
         "$IKA/IKA32010.sv" || exit 1

fail=0; itot=0; ttot=0; tol=0
for s in $(seq 0 $((SEEDS-1))); do
    # --- instruction level
    ./ref32010 dsp_real.hex 0 toaplantrace "$INSNS" "$s" > ref_it.trace 2>/dev/null
    ./tb.out +prog=dsp_real.hex +free=900000 +hseed="$s" +itrace=1 >/dev/null 2>&1
    n=$(wc -l < ref_it.trace); m=$(wc -l < rtl.tlog)
    c=$(( n < m ? n : m ))
    head -n "$c" ref_it.trace > a.t; head -n "$c" rtl.tlog > b.t
    # itrace_cmp.awk tolerates the two IKA32010 differences Wardner cannot see
    if res=$(paste -d'|' a.t b.t | awk -f itrace_cmp.awk); then
        itot=$((itot+c)); tol=$((tol+$(echo "$res" | grep -oE '[0-9]+ OVM' | cut -d' ' -f1)
                                 +$(echo "$res" | grep -oE '[0-9]+ INTM' | cut -d' ' -f1)))
    else echo "seed $s: instruction trace diverges"; echo "$res"; fail=1; fi

    # --- transaction level
    ./ref32010 dsp_real.hex 0 toaplanfree "$INSNS" "$s" > ref_tx.tlog 2>/dev/null
    ./tb.out +prog=dsp_real.hex +free=900000 +hseed="$s" >/dev/null 2>&1
    n=$(wc -l < ref_tx.tlog); m=$(wc -l < rtl.tlog)
    if [ "$n" -gt "$m" ]; then echo "seed $s: RTL transaction budget too small"; fail=1; continue; fi
    head -n "$n" rtl.tlog > b.t
    if diff -q ref_tx.tlog b.t >/dev/null; then ttot=$((ttot+n));
    else echo "seed $s: transaction log diverges"; diff ref_tx.tlog b.t | head -6; fail=1; fi
done
rm -f a.t b.t
if [ $fail -eq 0 ]; then
    echo "real Wardner DSP program: PASS"
    echo "  $itot instructions and $ttot transaction events compared across $SEEDS host RAM seeds"
    echo "  $tol instruction lines differed only in a tolerated status bit (see itrace_cmp.awk)"
else
    echo "real Wardner DSP program: FAIL"
fi
exit $fail
