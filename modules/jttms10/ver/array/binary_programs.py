#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent architectural binary PIXBLT boundary programs.

Run with ver/run.py --timed-word. These check values and canaries, not timing;
the separate TI timing oracle owns clock and physical bus expectations.
"""
import argparse
import random
from pathlib import Path

import yaml

from programs import blocks, read_bits, write_bits


def make_case(size, xy, layout):
    pixels = 16 // size
    columns, rows = 2*pixels, 2
    source, destination = 0x200, 0x800
    source_pitch, destination_pitch = 0x90, 0x100
    if layout == 'source_lane':
        source += 3
    elif layout == 'destination_lane':
        destination += size
    elif layout == 'source_pitch':
        source_pitch += 1
    elif layout == 'destination_pitch':
        destination_pitch += size
    elif layout == 'partial':
        columns = max(1, pixels-1)
    elif layout == 'wide':
        columns = 33
    elif layout != 'aligned':
        raise ValueError(layout)
    color0, color1 = 0x13572468, 0x2468ace1
    initial = {}
    rng = random.Random(34010 + size)
    for base, pitch, span in ((source, source_pitch, columns),
                              (destination, destination_pitch, columns*size)):
        for row in range(rows):
            for index in range((base+row*pitch)//16-1,
                               (base+row*pitch+span-1)//16+2):
                initial.setdefault(index, rng.getrandbits(16))
    expected = initial.copy()
    for row in range(rows):
        for pixel in range(columns):
            bit = read_bits(initial, source+row*source_pitch+pixel, 1)
            address = destination+row*destination_pitch+pixel*size
            value = (color1 if bit else color0) >> (address & 15)
            write_bits(expected, address, size, value)
    # CONVDP=23 gives 256 bits per Y. OFFSET and nonzero Y are independent
    # of the row pitch; destination_lane is representable at every PS.
    destination_xy = (2 << 16) | ((destination-0x800)//size)
    bregs = {0: source, 1: source_pitch,
             2: destination_xy if xy else destination, 3: destination_pitch,
             4: 0x600, 7: (rows << 16) | columns, 8: color0, 9: color1}
    words, checks = [], []
    pc = 0x1000
    for register, value in sorted(bregs.items()):
        words.extend((0x09f0 | register, value & 65535, value >> 16))
        checks.append(dict(after=pc, pc=pc+0x30, regs={f'B{register}': value}))
        pc += 0x30
    words.append(0x0fa0 if xy else 0x0f80)
    final_regs = {f'B{q}': value for q, value in bregs.items()}
    final_regs.update(B0=source+rows*source_pitch,
                      B2=destination+rows*destination_pitch)
    checks.append(dict(after=pc, pc=pc+0x10, regs=final_regs,
                       mem=[dict(addr=q*16,size=16,value=value)
                            for q,value in sorted(expected.items())]))
    return dict(name=f'binary_{"bxy" if xy else "bl"}_ps{size}_{layout}',
                entry=0x1000, pixel_size=size, convdp=23, convsp=23,
                watchdog_clocks=100000,
                control=0, pmask=0, words=words, checks=checks, mem=blocks(initial))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    cases = [make_case(size, xy, layout) for size in (1,2,4,8,16)
             for xy in (False,True)
             for layout in ('aligned','source_lane','destination_lane',
                            'source_pitch','destination_pitch','partial','wide')]
    args.out.write_text(yaml.safe_dump(dict(cases=cases), sort_keys=False))


if __name__ == '__main__':
    main()
