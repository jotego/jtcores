#!/usr/bin/env bash
# Full regression for jt32010: fuzz against the C reference model across
# interrupt rates and HALT duty cycles.
set -u
cd "$(dirname "$0")"
gcc -O2 -o ref32010 ref32010.c || exit 1
iverilog -g2005 -o tb.out tb_jt32010.v ../../hdl/jt32010.v || exit 1

STEPS=${STEPS:-20000}
fail=0; n=0
run(){ # seed irq hold
    python3 gen_prog.py "$1" prog.hex
    ./ref32010 prog.hex "$STEPS" "$2" > ref.trace 2>/dev/null
    ./tb.out +prog=prog.hex +steps="$STEPS" +irq="$2" +hold="$3" +seed="$1" > /dev/null
    n=$((n+1))
    if ! diff -q ref.trace rtl.trace > /dev/null; then
        echo "FAIL seed=$1 irq=$2 hold=$3"
        diff ref.trace rtl.trace | head -4 | sed 's/^/  /'
        fail=1
    fi
}
for s in $(seq 1 30); do run "$s" 0  0;  done
for s in $(seq 1 15); do run "$s" 97 0;  done
for s in $(seq 1 10); do run "$s" 23 0;  done
for s in $(seq 1 10); do run "$s" 7  0;  done
for s in $(seq 1 8);  do run "$s" 97 35; done
for s in $(seq 1 8);  do run "$s" 0  80; done
if [ $fail -eq 0 ]; then
    echo "jt32010 regression: PASS  ($n programs x $STEPS instructions)"
else
    echo "jt32010 regression: FAIL"
fi
exit $fail
