#!/usr/bin/env python3
"""Emit seeded FILL/PIXBLT programs with independent bit-addressed expectations.

The oracle uses Python integers to model whole memory words and TI's pixel
Boolean/arithmetic definitions. It never imports RTL or the HDL pixel helper.
Examples:
  python3 modules/jttms10/ver/array/programs.py --out /tmp/array.yaml
  python3 modules/jttms10/ver/run.py --vectors /tmp/array.yaml
  python3 modules/jttms10/ver/reference.py --vectors /tmp/array.yaml
"""

import argparse
import random
from pathlib import Path

import yaml


FORMS = (
    ("fill_l", 0x0FC0, None, "linear"),
    ("fill_xy", 0x0FE0, None, "xy"),
    ("blt_ll", 0x0F00, "linear", "linear"),
    ("blt_lxy", 0x0F20, "linear", "xy"),
    ("blt_xyl", 0x0F40, "xy", "linear"),
    ("blt_xyxy", 0x0F60, "xy", "xy"),
    ("blt_bl", 0x0F80, "binary", "linear"),
    ("blt_bxy", 0x0FA0, "binary", "xy"),
)
SIZES = (1, 2, 4, 8, 16)


def read_bits(words, address, width):
    value = 0
    for bit in range(width):
        location = address + bit
        value |= ((words[location // 16] >> (location % 16)) & 1) << bit
    return value


def write_bits(words, address, width, value):
    for bit in range(width):
        location = address + bit
        index = location // 16
        mask = 1 << (location % 16)
        words[index] = (words[index] & ~mask) | (mask if value & (1 << bit) else 0)


def pixel_op(code, source, dest, width):
    """Guide §7.7 equations; Python precision is unlimited until pixel masking."""
    limit = (1 << width) - 1
    if code == 0: result = source
    elif code == 1: result = source & dest
    elif code == 10: result = source ^ dest
    elif code == 16: result = source + dest
    elif code == 19: result = max(0, dest - source)
    elif code == 20: result = max(source, dest)
    elif code == 21: result = min(source, dest)
    else: raise ValueError(f"unsupported oracle PPOP {code}")
    return result & limit


def blocks(words):
    """Compact separately initialized source and destination word islands."""
    output = []
    keys = sorted(words)
    start = previous = keys[0]
    values = [words[start]]
    for index in keys[1:]:
        if index == previous + 1:
            values.append(words[index])
        else:
            output.append({"at": start * 16, "words": values})
            start, values = index, [words[index]]
        previous = index
    output.append({"at": start * 16, "words": values})
    return output


def make_case(form_index, width, sample, rng, *, fill_layout=None):
    label, opcode, source_kind, dest_kind = FORMS[form_index]
    columns = 2 + ((form_index + sample) & 1)
    rows = 1 + ((form_index + width + sample) % 3)
    pitch = (0x80, 0x100)[sample & 1]
    conv = 31 - (pitch.bit_length() - 1)
    src_x = 1 + (sample & 1)
    dst_x = 1 + ((form_index + sample) & 1)
    if fill_layout is not None:
        if source_kind is not None:
            raise ValueError('fill layout requires a FILL opcode')
        columns, rows, dst_x = fill_layout
    source_start = 0x200 + (14 if source_kind == "binary" and sample & 1
                            else 3 if source_kind == "binary" else src_x * width)
    dest_start = 0x600 + dst_x * width
    dest_y = 0x400 // pitch
    color0 = rng.getrandbits(16)
    color1 = rng.getrandbits(16)
    pmask = 0 if not (sample & 1) else rng.getrandbits(16)
    transparent = bool(sample & 1)
    codes = (0, 1, 10) if width in (1, 2) else (0, 1, 10, 16, 19, 20, 21)
    code = codes[(form_index * 3 + sample) % len(codes)]
    control = (code << 10) | (0x20 if transparent else 0)
    # TI FILL and binary PIXBLT transfer forward and ignore PBH/PBV.
    if source_kind in (None, "binary"):
        control |= (sample & 3) << 8
    if fill_layout is not None:
        code, pmask, transparent, control = 0, 0, False, 0
    mask = (1 << width) - 1

    initial = {}
    # Initialize each touched row plus one neighboring word on either side.
    for base, step in ((dest_start, width),
                       (source_start, 1 if source_kind == "binary" else width)):
        if base == source_start and source_kind is None:
            continue
        for row in range(rows):
            low = (base + row * pitch) // 16 - 1
            high = (base + row * pitch + (columns - 1) * step + step - 1) // 16 + 1
            for index in range(low, high + 1):
                initial.setdefault(index, rng.getrandbits(16))
    if source_kind == "binary":
        for row in range(rows):
            for col in range(columns):
                write_bits(initial, source_start + row * pitch + col, 1, rng.getrandbits(1))

    expected = initial.copy()
    for row in range(rows):
        for col in range(columns):
            destination = dest_start + row * pitch + col * width
            old_dest = read_bits(expected, destination, width)
            lane = destination & 15
            if source_kind is None:
                source = (color1 >> lane) & mask
            elif source_kind == "binary":
                bit = read_bits(initial, source_start + row * pitch + col, 1)
                source = ((color1 if bit else color0) >> lane) & mask
                # The bitmap bit selects COLOR0/1 before the expanded pixel
                # enters the plane-masked graphics processing path.
                source &= ~((pmask >> lane) & mask)
            else:
                address = source_start + row * pitch + col * width
                source = read_bits(initial, address, width)
                source &= ~((pmask >> (address & 15)) & mask)
            protected = (pmask >> lane) & mask
            visible_dest = old_dest & ~protected
            result = pixel_op(code, source, visible_dest, width) & ~protected
            if not (transparent and result == 0):
                write_bits(expected, destination, width,
                           (old_dest & protected) | result)

    bregs = {}
    if source_kind is not None:
        bregs[0] = (src_x if source_kind == "xy" else source_start)
        bregs[1] = pitch
    bregs[2] = ((dest_y << 16) | dst_x) if dest_kind == "xy" else dest_start
    bregs[3] = pitch
    if source_kind == "xy" or dest_kind == "xy":
        bregs[4] = 0x200
    bregs[7] = (rows << 16) | columns
    if source_kind == "binary":
        bregs[8] = color0
        bregs[9] = color1
    elif source_kind is None:
        bregs[9] = color1

    words = []
    checks = []
    pc = 0x1000
    for register, value in sorted(bregs.items()):
        words.extend((0x09F0 | register, value & 0xFFFF, value >> 16))
        checks.append({"after": pc, "pc": pc + 0x30,
                       "regs": {f"B{register}": value}})
        pc += 0x30
    words.append(opcode)
    final_regs = {"B2": dest_start + rows * pitch if source_kind is not None
                  else dest_start + (rows - 1) * pitch + columns * width,
                  "B7": bregs[7]}
    if fill_layout is not None:
        final_regs.update({f'B{q}': value for q,value in bregs.items() if q!=2})
    if source_kind is not None:
        final_regs["B0"] = source_start + rows * pitch
    checks.append({"after": pc, "pc": pc + 0x10,
                   "regs": final_regs,
                   "mem": [{"addr": index * 16, "size": 16, "value": value}
                           for index, value in sorted(expected.items())]})
    return {"name": f"array_{label}_ps{width}_sample{sample}",
            "entry": 0x1000, "pixel_size": width,
            "convsp": conv, "convdp": conv,
            "control": control, "pmask": pmask,
            "mem": blocks(initial), "words": words, "checks": checks}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=34010)
    parser.add_argument("--samples", type=int, default=4)
    parser.add_argument('--fill-boundaries', action='store_true',
                        help='replace FILL: all pixel lanes, short edges and multiword mixed edges')
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if args.samples < 1:
        parser.error("--samples must be positive")
    rng = random.Random(args.seed)
    if args.fill_boundaries:
        cases = []
        for form in (0,1):
            for width in SIZES:
                pixels = 16 // width
                for lane in range(pixels):
                    for columns in sorted({max(1,pixels-1),2*pixels+1}):
                        case = make_case(form,width,0,rng,fill_layout=(columns,2,lane))
                        case['name'] = f'fill_boundary_{form}_ps{width}_lane{lane}_dx{columns}'
                        cases.append(case)
    else:
        cases = [make_case(form, width, sample, rng)
                 for form in range(len(FORMS))
                 for width in SIZES
                 for sample in range(args.samples)]
    args.out.write_text(yaml.safe_dump({"array_seed": args.seed, "cases": cases},
                                       sort_keys=False))
    print(f"wrote {len(cases)} array programs (seed {args.seed}) to {args.out}")


if __name__ == "__main__":
    main()
