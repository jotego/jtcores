#!/usr/bin/env bash
# Mutation test for the Toaplan DSP subsystem.
#
# A conformance suite that cannot fail is worth nothing, so this deliberately
# breaks the wrapper in ways a careless implementation plausibly would, and
# checks the suite notices each one. Every mutation must be caught either by
# the transaction diff or by a property violation.
set -u
cd "$(dirname "$0")"
SRC=../../hdl/jttoaplan1_dsp.v
GOOD=$(mktemp); cp "$SRC" "$GOOD"
trap 'cp "$GOOD" "$SRC"; rm -f "$GOOD"' EXIT

build(){ iverilog -g2005 -o tb.out tb_dsp.v "$SRC" \
         ../../../../modules/jt32010/hdl/jt32010.v; }

apply(){ python3 -c "
import sys
s=open('$GOOD').read()
old=sys.argv[1]; new=sys.argv[2]
assert old in s, 'mutation pattern not found: '+old[:40]
open('$SRC','w').write(s.replace(old,new))" "$1" "$2"; }

# returns 0 if the suite noticed the fault
detected(){
    build >/dev/null 2>&1 || return 0            # a mutation that will not compile counts
    ./run.sh 3 >/dev/null 2>&1 || return 0       # transaction diff caught it
    for extra in "+abortwr=1" "+tail=300" "+tail=2500"; do
        for p in dsp edge; do
            ./tb.out +prog=$p.hex +acts=3 $extra 2>/dev/null \
                | grep -q "PROPERTY VIOLATIONS" && return 0
        done
    done
    return 1
}

pass=0; miss=0
check(){ # name old new
    local name="$1"; shift
    apply "$1" "$2"
    if detected; then echo "  caught   : $name"; pass=$((pass+1))
    else             echo "  MISSED   : $name"; miss=$((miss+1)); fi
    cp "$GOOD" "$SRC"
}

echo "mutation test:"
check "release arm ignores the word address" \
      "(addr_l[12:1] == 12'd0) && " ""
check "release arm ignores the value written" \
      "&& (pdout == 16'd0)" ""
check "port 3 zero releases the host without the arm" \
      "if( execute ) begin
                            halt_main <= 1'b0;   // the host runs again
                            execute   <= 1'b0;
                        end" \
      "begin
                            halt_main <= 1'b0;
                            execute   <= 1'b0;
                        end"
check "sprite RAM decoded as work RAM" \
      "3'b100:  sel_new = SEL_OBJ;" "3'b100:  sel_new = SEL_WORK;"
check "invalid window treated as work RAM" \
      "default: sel_new = SEL_NONE;" "default: sel_new = SEL_WORK;"
check "window offset one bit too narrow" \
      "{2'd0, pdout[10:0]}" "{3'd0, pdout[9:0]}"
check "port strobes not gated by the run bit" \
      "wire dsp_step = cen & dsp_on;" "wire dsp_step = cen;"
check "interrupt held as a level instead of a pulse" \
      "            irq_pulse <= 1'b1;" \
      "            irq_pulse <= 1'b1;
        end
        if( dsp_on ) begin
            irq_pulse <= 1'b1;"
check "BIO not set on the closing port 3 write" \
      "                        bio <= 1'b1;" "                        bio <= bio;"

echo "mutation test: $pass caught, $miss missed"
[ $miss -eq 0 ]
