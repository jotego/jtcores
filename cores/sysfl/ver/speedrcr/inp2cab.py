#!/usr/bin/env python3
# MAME per-frame port log (mame_scripts/log_ports.lua) -> jtsim .cab
# pedal/wheel keys are recovered from the ADC steps modelled by jtsysfl_ctrl.v
import sys

def step(acc, whl, gas, left, right):
    acc = min(acc+20, 0xff) if gas else max(acc-20, 0)
    if right and not left:   whl = min(whl+4, 0xff)
    elif left and not right: whl = max(whl-4, 0)
    elif whl > 0x84: whl -= 4
    elif whl < 0x7c: whl += 4
    else: whl = 0x80
    return acc, whl

src = sys.argv[1] if len(sys.argv) > 1 else "speed1_ports.txt"
dst = sys.argv[2] if len(sys.argv) > 2 else "speed1.cab"
# optional: frame of the first input in the sim (fastboot reaches attract earlier)
first = int(sys.argv[3]) if len(sys.argv) > 3 else None
rows = [[int(x, 16) for x in l.split()[1:]] for l in open(src)]
n = len(rows)
keys = [set() for _ in range(n)]
acc, whl = 0, 0x80
for f, (misc, in1, in2, a, w) in enumerate(rows):
    if not misc & 0x20: keys[f].add("coin")
    if not misc & 0x80: keys[f].add("service")
    if not in2 & 0x80:  keys[f].add("1p")
    for b, k in ((0x20, "b2"), (0x40, "b3")):
        if not in2 & b: keys[f].add(k)
    for gas in (0, 1):
        for lr in ((0, 0), (1, 0), (0, 1)):
            if step(acc, whl, gas, *lr) == (a, w):
                break
        else:
            continue
        break
    else:
        sys.exit(f"frame {f}: no key combination gives accel {a:02x} wheel {w:02x}")
    acc, whl = a, w
    # ADC steps at the end of the frame in the RTL, so press one frame earlier
    tgt = keys[max(f-1, 0)]
    if gas:   tgt.add("b1")
    if lr[0]: tgt.add("left")
    if lr[1]: tgt.add("right")

skip = 0
if first is not None:
    skip = max(0, next(f for f in range(n) if keys[f]) - first)
    keys = keys[skip:]
    n = len(keys)

with open(dst, "w") as out:
    out.write(f"# {src}: {n} frames, first {skip} idle frames dropped, converted by inp2cab.py\n")
    f = 0
    while f < n:
        g = f
        while g < n and keys[g] == keys[f]: g += 1
        out.write(f"{g-f} {' '.join(sorted(keys[f]))}".rstrip() + "\n")
        f = g
print(f"{dst}: {n} frames")
