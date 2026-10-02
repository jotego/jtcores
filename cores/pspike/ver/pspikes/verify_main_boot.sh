#!/bin/bash
# Compare the FPGA 68000 fetch stream against MAME's boot trace.
#
#   FRAMES=140 ROMS_HOST=~/mameroms ./sim-core.sh pspike pspikes
#   cores/pspike/ver/pspikes/verify_main_boot.sh
#
# Both traces are reduced to their CODE PATH: the order in which each address
# is reached for the first time. That is immune to the two things that make a
# raw line-by-line diff useless here:
#   - 68000 prefetch, which adds fetches MAME never executes (the word after a
#     taken branch, e.g. 0006a4 right after "bra $6a8")
#   - loop iteration counts, which drift by tens of thousands of lines across
#     the 65k-iteration RAM test
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
JTROOT=$(cd "$HERE/../../../.." && pwd)
MAME_TR=${MAME_TR:-$HERE/traces/main_boot.tr}
FPGA_TR=${FPGA_TR:-$JTROOT/cores/pspike/ver/game/pspike_main_fpga.tr}

[ -f "$MAME_TR" ] || { echo "missing MAME trace $MAME_TR" >&2; exit 1; }
[ -f "$FPGA_TR" ] || { echo "missing FPGA trace $FPGA_TR - run the sim first" >&2; exit 1; }

MAME_TR="$MAME_TR" FPGA_TR="$FPGA_TR" python3 - <<'EOF'
import os, re, sys

def pcs(path):
    out = []
    with open(path) as f:
        for line in f:
            m = re.match(r'^([0-9A-Fa-f]{6}):', line)
            if m:
                out.append((int(m.group(1), 16), line.rstrip()))
    return out

def first_seen(seq):
    "ordered list of addresses, each kept only the first time it appears"
    seen, out = set(), []
    for pc, text in seq:
        if pc not in seen:
            seen.add(pc)
            out.append((pc, text))
    return out

mame, fpga = pcs(os.environ['MAME_TR']), pcs(os.environ['FPGA_TR'])
print(f"MAME {len(mame)} instructions, FPGA {len(fpga)} program fetches")
if not fpga:
    print("FAIL: the FPGA never fetched anything. CPU is dead.")
    sys.exit(1)

mpath, fpath = first_seen(mame), first_seen(fpga)
fset = {pc for pc, _ in fpath}
fpos = {pc: i for i, (pc, _) in enumerate(fpath)}
print(f"code path: MAME reaches {len(mpath)} addresses, FPGA {len(fpath)}")

prev = -1
for i, (pc, text) in enumerate(mpath):
    if pc not in fset:
        print(f"\nDIVERGE: MAME reaches {pc:06X} but the FPGA never does")
        print(f"  {text}")
        print("\n  MAME path before it:")
        for t in mpath[max(0, i - 8):i]:
            print("   ", t[1])
        sys.exit(1)
    prev = fpos[pc]

print(f"OK: every one of the {len(mpath)} addresses MAME executes is reached by the FPGA")
extra = len(fpath) - len(mpath)
if extra > 0:
    print(f"     (the FPGA also fetched {extra} addresses MAME never executed - prefetch)")
EOF
