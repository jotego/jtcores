#!/bin/bash
# Scene-only simulation. The CPU is not simulated
game=$(basename $(pwd))

log=$(rsync -ai --exclude='*/' --out-format='%i %n%L' ~/.mame/debug/$game/* .)
printf '%s\n' "$log"
if printf '%s\n' "$log" | grep -qv '^[.]'; then
	jtutil sdram --sim
fi

jtsim -d VERILATOR_KEEP_LFBUF -d VERILATOR_KEEP_SDRAM -d NOMAIN -d SCENE -d SPRDMA -video 3 -w $*
