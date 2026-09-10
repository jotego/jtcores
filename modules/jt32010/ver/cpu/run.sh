#!/usr/bin/env bash
# Fuzz jt32010 against the C reference model.
# usage: ./run.sh [seeds] [steps] [irq_period]
#   irq_period 0 disables interrupts; N raises one every N instructions.
set -u
cd "$(dirname "$0")"
SEEDS=${1:-20}
STEPS=${2:-20000}
IRQ=${3:-0}

gcc -O2 -o ref32010 ref32010.c || exit 1
iverilog -g2005 -o tb.out tb_jt32010.v ../../hdl/jt32010.v || exit 1

fail=0
for s in $(seq 1 "$SEEDS"); do
    python3 gen_prog.py "$s" prog.hex
    ./ref32010 prog.hex "$STEPS" "$IRQ" > ref.trace
    ./tb.out +prog=prog.hex +steps="$STEPS" +irq="$IRQ" > /dev/null
    if diff -q ref.trace rtl.trace > /dev/null; then
        echo "seed $s: PASS"
    else
        echo "seed $s: FAIL"
        echo "  first divergence (ref | rtl):"
        diff ref.trace rtl.trace | head -6 | sed 's/^/  /'
        line=$(diff --unchanged-line-format= --old-line-format='%dn
' --new-line-format= ref.trace rtl.trace | head -1)
        if [ -n "$line" ]; then
            echo "  context, ref trace lines $((line>3?line-3:1))..$((line+1)):"
            sed -n "$((line>3?line-3:1)),$((line+1))p" ref.trace | sed 's/^/    ref /'
            sed -n "$((line>3?line-3:1)),$((line+1))p" rtl.trace | sed 's/^/    rtl /'
        fi
        fail=1
        break
    fi
done
[ $fail -eq 0 ] && echo "ALL SEEDS PASS"
exit $fail
