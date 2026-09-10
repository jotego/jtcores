#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build the main Z80's 0x40000 program region for simulation.

MAME's wardnerb "maincpu" region, with ROMREGION_ERASEFF, is:

    0x00000  b25-31.6m   32 KB   fixed code at 0000-6FFF
    0x10000  b25-18.7m   64 KB   banks 2 and 3
    0x20000  b25-19.8m   64 KB   banks 4 and 5
    0x38000  b25-32.10m  32 KB   bank 7

Banks 1 and 6 are unpopulated and read as FF. Port 0x70 selects bank
(value & 7); a value of zero instead puts the sprite, palette and sound RAMs
back in the read path at 8000-FFFF.

The bootleg set names those files wardner.17, b25-18.rom, b25-19.rom and
wardner.20; the parent set's names are accepted too.

Also writes the sound CPU's 32 KB program as snd.hex alongside it.

usage: mkrom.py <rom dir> [out.hex] [snd.hex]
"""
import sys, os

# (destination offset, size, candidate filenames)
PARTS = [
    (0x00000, 0x8000, ["wardner.17", "b25-31.6m", "17.bin"]),
    (0x10000, 0x10000, ["b25-18.rom", "b25-18.7m", "18.bin"]),
    (0x20000, 0x10000, ["b25-19.rom", "b25-19.8m", "19.bin"]),
    (0x38000, 0x8000, ["wardner.20", "b25-32.10m", "20.bin"]),
]

def find(d, names):
    for n in names:
        p = os.path.join(d, n)
        if os.path.isfile(p):
            return p
    raise SystemExit("mkrom: none of %s found in %s" % (", ".join(names), d))

def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: mkrom.py <rom dir> [out.hex]")
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "main.hex"
    rom = bytearray(b"\xff" * 0x40000)
    for off, size, names in PARTS:
        p = find(src, names)
        d = open(p, "rb").read()
        if len(d) != size:
            raise SystemExit("mkrom: %s is %d bytes, expected %d" % (p, len(d), size))
        rom[off:off+size] = d
        print("  %05x  %-14s %d bytes" % (off, os.path.basename(p), size))
    with open(out, "w") as f:
        for b in rom:
            f.write("%02x\n" % b)
    print("wrote %s (%d bytes)" % (out, len(rom)))
    print("reset vector area: %s" % " ".join("%02x" % b for b in rom[0:8]))

    # the sound CPU's ROM is a straight 32 KB at 0000
    sndout = sys.argv[3] if len(sys.argv) > 3 else "snd.hex"
    sp = find(src, ["b25-16.rom", "b25-16.4k", "16.bin"])
    sd = open(sp, "rb").read()
    if len(sd) != 0x8000:
        raise SystemExit("mkrom: %s is %d bytes, expected 32768" % (sp, len(sd)))
    with open(sndout, "w") as f:
        for b in sd:
            f.write("%02x\n" % b)
    print("wrote %s from %s" % (sndout, os.path.basename(sp)))
    print("sound reset vector: %s" % " ".join("%02x" % b for b in sd[0:4]))

main()
