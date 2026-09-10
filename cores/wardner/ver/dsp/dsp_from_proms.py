#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""Rebuild the Wardner TMS320C10 program from the bootleg set's nibble PROMs.

The wardnerb set dumps the DSP's internal mask ROM as eight 4-bit PROMs. MAME
loads them with ROM_NIBBLE | ROM_SHIFT_NIBBLE_HI/LO | ROM_SKIP(1) into a
ROM_REGION16_BE, which means:

  even byte (MSB of the big-endian word) = HI PROM nibble << 4 | LO PROM nibble
  odd  byte (LSB)                        = the other HI/LO pair

Words 0x000-0x3ff come from the 82s137 pairs, words 0x400-0x5ff from the
82s131 pairs, giving the 0x600 words the part actually contains.

This is worth having as code because jtframe's mame2mra has no nibble
transform, so the MRA cannot assemble this set; the .rom has to carry the
already-assembled program.

usage: dsp_from_proms.py <dir with the PROMs> [out.hex] [out.bin]
"""
import sys, os, zlib, hashlib

PAIRS = [
    # dest byte offset, count, HI(msb) LO(msb) HI(lsb) LO(lsb)
    (0x0000, 0x400, "82s137.1d", "82s137.1e", "82s137.3d", "82s137.3e"),
    (0x0800, 0x200, "82s131.3b", "82s131.3a", "82s131.2a", "82s131.1a"),
]

def nibbles(path, n):
    d = open(path, "rb").read()
    if len(d) != n:
        raise SystemExit("%s: expected %d bytes, got %d" % (path, n, len(d)))
    return [b & 0x0f for b in d]

def build(src):
    rom = bytearray(0x1000)
    for base, cnt, hi, lo, hi2, lo2 in PAIRS:
        a = nibbles(os.path.join(src, hi),  cnt)
        b = nibbles(os.path.join(src, lo),  cnt)
        c = nibbles(os.path.join(src, hi2), cnt)
        d = nibbles(os.path.join(src, lo2), cnt)
        for i in range(cnt):
            rom[base + 2*i]     = (a[i] << 4) | b[i]
            rom[base + 2*i + 1] = (c[i] << 4) | d[i]
    return rom

def main():
    src  = sys.argv[1] if len(sys.argv) > 1 else "."
    hexf = sys.argv[2] if len(sys.argv) > 2 else "dsp_wardnerb.hex"
    binf = sys.argv[3] if len(sys.argv) > 3 else None
    rom  = build(src)
    used = bytes(rom[:0xc00])
    with open(hexf, "w") as f:
        for i in range(0x800):
            f.write("%04x\n" % ((rom[2*i] << 8) | rom[2*i+1]))
        # the PC is 12 bits wide but only 0x000-0x7ff is mapped; pad the rest
        # with zero so a simulator sees what the hardware would.
        for i in range(0x800, 0x1000):
            f.write("0000\n")
    if binf:
        open(binf, "wb").write(used)
    w0 = (rom[0] << 8) | rom[1]
    w2 = (rom[4] << 8) | rom[5]
    ok = (w0 & 0xff00) == 0xf900 and (w2 & 0xff00) == 0xf900
    print("words 0x600, crc32 %08x, sha1 %s"
          % (zlib.crc32(used) & 0xffffffff, hashlib.sha1(used).hexdigest()))
    print("reset vector  B $%03x" % ((rom[2] << 8) | rom[3]))
    print("int   vector  B $%03x" % ((rom[6] << 8) | rom[7]))
    print("vector sanity: %s" % ("OK" if ok else "FAILED - both vectors should be B"))
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
