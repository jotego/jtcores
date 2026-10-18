#!/bin/bash
cd "$(dirname "$0")"
JT49=../../../../modules/jt12/jt49/hdl
OUT=$(mktemp -d)
FAIL=0
for DEF in "" "-DNOSOUND"; do
    echo "=== run ${DEF:-normal}"
    iverilog -g2012 $DEF -o $OUT/sim -s test test.v ../../hdl/jtpopeye_sound.v \
        $JT49/{jt49_bus,jt49,jt49_cen,jt49_div,jt49_eg,jt49_exp,jt49_noise}.v || { FAIL=1; continue; }
    vvp -n $OUT/sim | tee $OUT/sim.log
    if ! grep -q "^PASS" $OUT/sim.log || grep -q ERROR $OUT/sim.log; then FAIL=1; fi
done
rm -rf $OUT
exit $FAIL
