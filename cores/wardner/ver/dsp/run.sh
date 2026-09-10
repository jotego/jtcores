#!/usr/bin/env bash
# Transaction-level conformance test for the Toaplan DSP subsystem.
# Diffs the RTL's host-visible event log against the C reference model, for
# each test program and across several host idle times.
set -u
cd "$(dirname "$0")"
REF=../../../../modules/jt32010/ver/cpu
ACTS=${1:-6}

python3 prog_protocol.py dsp.hex  > /dev/null || exit 1
python3 prog_edge.py     edge.hex > /dev/null || exit 1
gcc -O2 -o "$REF/ref32010" "$REF/ref32010.c" || exit 1
iverilog -g2005 -o tb.out tb_dsp.v ../../hdl/jttoaplan1_dsp.v \
         ../../../../modules/jt32010/hdl/jt32010.v || exit 1

fail=0
for prog in dsp edge; do
    "$REF/ref32010" "$prog.hex" 4000 toaplan "$ACTS" > ref.tlog || exit 1
    # The handshake is a strict sequence, so how long the host idles between
    # activations must not change the transaction log at all.
    for tail in 300 900 2500; do
        ./tb.out +prog="$prog.hex" +acts="$ACTS" +tail="$tail" > /dev/null || exit 1
        if diff -u ref.tlog rtl.tlog > tlog.diff; then
            printf "  %-5s tail=%-5s PASS (%s events)\n" "$prog" "$tail" "$(wc -l < ref.tlog)"
        else
            printf "  %-5s tail=%-5s FAIL\n" "$prog" "$tail"
            head -20 tlog.diff
            fail=1
        fi
    done
done
rm -f tlog.diff
if [ $fail -eq 0 ]; then
    echo "toaplan dsp transaction test: PASS"
else
    echo "toaplan dsp transaction test: FAIL"
fi
exit $fail
