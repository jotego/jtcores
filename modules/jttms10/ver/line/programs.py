#!/usr/bin/env python3
"""Generate LINE programs from the TI §12-99–104 Bresenham specification.

The oracle computes signed decision steps and bit-addressed pixels in Python;
it does not use the HDL LINE or pixel helpers. Run with --out and pass that
file to ver/run.py and ver/reference.py using their --vectors option.
"""

import argparse
from pathlib import Path

import yaml


def u32(value):
    return value & 0xFFFFFFFF


def s32(value):
    value = u32(value)
    return value - 0x100000000 if value & 0x80000000 else value


def xy(x, y):
    return ((y & 0xFFFF) << 16) | (x & 0xFFFF)


def add_xy(value, increment):
    return xy((value + increment) & 0xFFFF,
              ((value >> 16) + (increment >> 16)) & 0xFFFF)


def bit_addr(point, psize):
    x = point & 0xFFFF
    y = (point >> 16) & 0xFFFF
    if x & 0x8000:
        x -= 0x10000
    if y & 0x8000:
        y -= 0x10000
    if x < 0 or y < 0:
        raise ValueError("oracle memory cases keep XY nonnegative")
    return 0x200 + ((y << 7) | (x * psize))


def read_bits(words, addr, width):
    return sum(((words[addr // 16] >> (addr % 16)) & 1) << bit
               for bit, addr in enumerate(range(addr, addr + width)))


def write_bits(words, addr, width, value):
    for bit in range(width):
        location = addr + bit
        index = location // 16
        mask = 1 << (location % 16)
        words[index] = ((words[index] & ~mask) |
                        (mask if value & (1 << bit) else 0))


def blocks(words):
    result = []
    for index in sorted(words):
        if result and result[-1]["at"] + 16 * len(result[-1]["words"]) == index * 16:
            result[-1]["words"].append(words[index])
        else:
            result.append({"at": index * 16, "words": [words[index]]})
    return result


def make_case(spec):
    name = spec["name"]
    psize = spec.get("psize", 4)
    zmode = spec.get("z", 0)
    count = spec["count"]
    a = spec["a"]
    b = spec["b"]
    d = spec["d"]
    point = xy(*spec["start"])
    inc1 = xy(*spec["inc1"])
    inc2 = xy(*spec["inc2"])
    wmode = spec.get("window", 0)
    start = spec.get("wstart", (0, 0))
    end = spec.get("wend", (15, 15))
    color = spec.get("color", 0x77777777)
    pmask = spec.get("pmask", 0)
    ppop = spec.get("ppop", 0)
    transparent = spec.get("transparent", False)
    if ppop not in (0, 10):
        raise ValueError("oracle currently handles replace/XOR")

    # Draw locations are calculated before setting expected memory. This also
    # includes window-inhibited pixels, so they are checked for preservation.
    locations = []
    initial_d, initial_point, initial_count = d, point, count
    vflag, wvp = 0, 0
    for _ in range(count):
        x, y = point & 0xFFFF, point >> 16
        sx = x - 0x10000 if x & 0x8000 else x
        sy = y - 0x10000 if y & 0x8000 else y
        inside = start[0] <= sx <= end[0] and start[1] <= sy <= end[1]
        draw = wmode == 0 or (wmode in (2, 3) and inside)
        locations.append((bit_addr(point, psize), draw))
        count -= 1
        if wmode == 1 and inside:
            vflag, wvp = 0, 1
            abort = True
        elif wmode == 2 and not inside:
            vflag, wvp = 1, 1
            abort = True
        else:
            if wmode == 3:
                vflag = 0 if inside else 1
            abort = False
        diagonal = s32(d) >= 0 if zmode else s32(d) > 0
        d = u32(d + 2 * b - (2 * a if diagonal else 0))
        point = add_xy(point, inc1 if diagonal else inc2)
        if abort:
            break
    if wmode == 1 and not wvp:
        vflag = 1
    if wmode == 2 and not wvp:
        vflag = 0

    memory = {}
    for address, _ in locations:
        for index in range(address // 16 - 1, (address + psize - 1) // 16 + 2):
            memory.setdefault(index, (0xA53C ^ (index * 0x1235)) & 0xFFFF)
    if not memory:
        memory[0x20] = 0xA53C
    expected = memory.copy()
    lane_mask = (1 << psize) - 1
    for address, draw in locations:
        if not draw:
            continue
        old = read_bits(expected, address, psize)
        protect = (pmask >> (address & 15)) & lane_mask
        source = (color >> (address & 15)) & lane_mask
        dest = old & ~protect
        result = (source ^ dest if ppop == 10 else source) & ~protect & lane_mask
        if not (transparent and result == 0):
            write_bits(expected, address, psize, result | (old & protect))

    regs = [
        (0, initial_d), (2, initial_point), (4, 0x200),
        (5, xy(*start)), (6, xy(*end)), (7, xy(a, b)),
        (9, color), (10, initial_count), (11, inc1), (12, inc2),
        (13, 0xFFFFFFFF), (14, 0x13579BDF),
    ]
    words, checks = [], []
    pc = 0x1000
    for register, value in regs:
        words += [0x09F0 | register, value & 0xFFFF, (value >> 16) & 0xFFFF]
        checks.append({"after": pc, "pc": pc + 0x30,
                       "regs": {f"B{register}": u32(value)}})
        pc += 0x30
    words.append(0xDF1A | (zmode << 7))
    checks.append({"after": pc, "pc": pc + 0x10,
                   "regs": {"B0": u32(d), "B2": point, "B10": count},
                   "flags": {"V": vflag}, "wvp": wvp,
                   "mem": [{"addr": index * 16, "size": 16, "value": value}
                           for index, value in sorted(expected.items())]})
    return {"name": name, "entry": 0x1000, "pixel_size": psize,
            "convdp": 24, "control": (ppop << 10) | (wmode << 6) |
            (0x20 if transparent else 0), "pmask": pmask,
            "words": words, "mem": blocks(memory), "checks": checks}


SPECS = [
    {"name": "line_count_zero", "start": (2, 2), "a": 0, "b": 0,
     "d": 0, "count": 0, "inc1": (1, 1), "inc2": (1, 0)},
    {"name": "line_tie_z0_uses_major", "start": (2, 2), "a": 2, "b": 1,
     "d": 0, "count": 1, "inc1": (1, 1), "inc2": (1, 0)},
    {"name": "line_tie_z1_uses_diagonal", "z": 1, "start": (2, 2),
     "a": 2, "b": 1, "d": 0, "count": 1,
     "inc1": (1, 1), "inc2": (1, 0)},
    {"name": "line_positive_diagonal", "start": (2, 2), "a": 2, "b": 2,
     "d": 2, "count": 3, "inc1": (1, 1), "inc2": (1, 0)},
    {"name": "line_negative_major", "start": (2, 2), "a": 3, "b": 0,
     "d": -3, "count": 4, "inc1": (1, 1), "inc2": (0, 1)},
    {"name": "line_window_hit", "start": (2, 2), "a": 3, "b": 0,
     "d": -3, "count": 4, "inc1": (1, 1), "inc2": (1, 0),
     "window": 1, "wstart": (4, 2), "wend": (4, 2)},
    {"name": "line_window_query_miss", "start": (2, 2), "a": 3, "b": 0,
     "d": -3, "count": 4, "inc1": (1, 1), "inc2": (1, 0),
     "window": 1, "wstart": (8, 2), "wend": (9, 2)},
    {"name": "line_window_abort", "start": (2, 2), "a": 3, "b": 0,
     "d": -3, "count": 4, "inc1": (1, 1), "inc2": (1, 0),
     "window": 2, "wstart": (2, 2), "wend": (3, 2)},
    {"name": "line_window_all_inside", "start": (2, 2), "a": 3, "b": 0,
     "d": -3, "count": 4, "inc1": (1, 1), "inc2": (1, 0),
     "window": 2, "wstart": (2, 2), "wend": (5, 2)},
    {"name": "line_window_clip_last_out", "start": (2, 2),
     "a": 3, "b": 0, "d": -3, "count": 4,
     "inc1": (1, 1), "inc2": (1, 0), "window": 3,
     "wstart": (3, 2), "wend": (4, 2)},
    {"name": "line_window_clip_last_in", "start": (2, 2),
     "a": 3, "b": 0, "d": -3, "count": 4,
     "inc1": (1, 1), "inc2": (1, 0), "window": 3,
     "wstart": (4, 2), "wend": (5, 2)},
    {"name": "line_xor_mask_transparent", "start": (2, 2),
     "a": 3, "b": 0, "d": -3, "count": 4,
     "inc1": (1, 1), "inc2": (1, 0), "color": 0x55555555,
     "ppop": 10, "pmask": 0x2222, "transparent": True},
]

for major in ("x", "y"):
    for xsign in (-1, 1):
        for ysign in (-1, 1):
            diagonal = (xsign, ysign)
            lateral = (xsign, 0) if major == "x" else (0, ysign)
            SPECS.append({
                "name": f"line_octant_{major}_{'neg' if xsign < 0 else 'pos'}x_"
                        f"{'neg' if ysign < 0 else 'pos'}y",
                "start": (6, 6), "a": 3, "b": 1, "d": -1,
                "count": 4, "inc1": diagonal, "inc2": lateral,
            })


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    cases = [make_case(spec) for spec in SPECS]
    args.out.write_text(yaml.safe_dump({"cases": cases}, sort_keys=False))
    print(f"wrote {len(cases)} LINE programs to {args.out}")


if __name__ == "__main__":
    main()
