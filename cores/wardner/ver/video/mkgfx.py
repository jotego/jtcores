#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build the graphics ROM images for simulation, laid out exactly as MAME's
regions so the reference renderer and the RTL read the same bytes.

  chars     0x0c000  b25-28, b25-27, b25-26   three 16 KB planes,  8x8 3bpp
  fg_tiles  0x20000  b25-12, b25-15, b25-14, b25-13   four 32 KB planes, 8x8 4bpp
  bg_tiles  0x20000  b25-08, b25-11, b25-10, b25-09   four 32 KB planes, 8x8 4bpp
  scu       0x40000  b25-01, b25-02, b25-03, b25-04   four 64 KB planes, 16x16 4bpp

Every layout uses RGN_FRAC(n,planes): plane p of a tile is a contiguous slice
of the region, one bit per pixel, MSB first, one byte (8x8) or two bytes
(16x16) per row.

usage: mkgfx.py <rom dir> [out dir]
"""
import sys, os

REGIONS = {
    "chars": [["wardner.07", "b25-28.10f", "7.bin"],
              ["wardner.06", "b25-27.8f",  "6.bin"],
              ["wardner.05", "b25-26.7f",  "5.bin"]],
    "fg":    [["b25-12.rom", "b25-12.18f", "12.bin"],
              ["b25-15.rom", "b25-15.23f", "15.bin"],
              ["b25-14.rom", "b25-14.21f", "14.bin"],
              ["b25-13.rom", "b25-13.19f", "13.bin"]],
    "bg":    [["b25-08.rom", "b25-08.12f", "8.bin"],
              ["b25-11.rom", "b25-11.16f", "11.bin"],
              ["b25-10.rom", "b25-10.15f", "10.bin"],
              ["b25-09.rom", "b25-09.14f", "9.bin"]],
    "obj":   [["b25-01.rom", "b25-01.14c", "1.bin"],
              ["b25-02.rom", "b25-02.16c", "2.bin"],
              ["b25-03.rom", "b25-03.17c", "3.bin"],
              ["b25-04.rom", "b25-04.19c", "4.bin"]],
}
SIZES = {"chars": 0x4000, "fg": 0x8000, "bg": 0x8000, "obj": 0x10000}

def find(d, names):
    for n in names:
        p = os.path.join(d, n)
        if os.path.isfile(p):
            return p
    raise SystemExit("mkgfx: none of %s in %s" % (", ".join(names), d))

def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "."
    out = sys.argv[2] if len(sys.argv) > 2 else "."
    for name, planes in REGIONS.items():
        data = bytearray()
        for names in planes:
            p = find(src, names)
            d = open(p, "rb").read()
            if len(d) != SIZES[name]:
                raise SystemExit("mkgfx: %s is %d bytes, expected %d" % (p, len(d), SIZES[name]))
            data += d
        bin_path = os.path.join(out, "gfx_%s.bin" % name)
        hex_path = os.path.join(out, "gfx_%s.hex" % name)
        open(bin_path, "wb").write(data)
        with open(hex_path, "w") as f:
            for b in data:
                f.write("%02x\n" % b)
        print("  %-5s %6d bytes  %d planes" % (name, len(data), len(planes)))
    return 0

sys.exit(main())
