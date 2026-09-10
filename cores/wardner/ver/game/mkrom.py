#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""Assemble the whole-core .rom image from a Wardner ROM set.

This is what cfg/mame2mra.toml is supposed to produce, built independently so
the two can be diffed. The layout is the one in cfg/macros.def:

    0x000000  main Z80   0x40000  sparse, the bank gaps stay 0xFF
    0x040000  sound Z80  0x08000
    0x048000  DSP        0x01000  16-bit words, byte swapped from the BE region
    0x049000  chars      0x10000  3 planes interleaved into 32-bit words
    0x059000  bg tiles   0x20000  4 planes
    0x079000  fg tiles   0x20000  4 planes
    0x099000  sprites    0x40000  4 planes
    0x0D9000  proms      0x00260

Byte order inside a 32-bit word is settled by jtframe's own ROM self-check
(jtframe_rom_2slots.v): a read returns { mem[a+1], mem[a] } over 16-bit words
that are loaded little endian, so the four bytes at increasing addresses land
in data[7:0], [15:8], [23:16] and [31:24]. The tile and sprite engines want
plane 0 in the low byte, so the planes are written plane 0 first.

usage: mkrom.py <rom dir> [out.rom]
"""
import sys, os, zlib

# (destination, size, candidate file names) - the parent set, the bootleg and
# the loose-numbered dumps all appear in the wild
MAIN = [
    (0x00000, 0x8000,  ["b25-31.6m",  "wardner.17", "17.bin"]),
    (0x10000, 0x10000, ["b25-18.7m",  "b25-18.rom", "18.bin"]),
    (0x20000, 0x10000, ["b25-19.8m",  "b25-19.rom", "19.bin"]),
    (0x38000, 0x8000,  ["b25-32.10m", "wardner.20", "20.bin"]),
]
SND = ["b25-16.4k", "b25-16.rom", "16.bin"]
DSP = ["d70012u_gxc-02_mcu_71001", "d70012u_gxc-02_mcu_71001.bin"]

PLANES = {
    "chars": (0x4000, [["b25-28.10f", "wardner.07", "7.bin"],
                       ["b25-27.8f",  "wardner.06", "6.bin"],
                       ["b25-26.7f",  "wardner.05", "5.bin"]]),
    "bg":    (0x8000, [["b25-08.12f", "b25-08.rom", "8.bin"],
                       ["b25-11.16f", "b25-11.rom", "11.bin"],
                       ["b25-10.15f", "b25-10.rom", "10.bin"],
                       ["b25-09.14f", "b25-09.rom", "9.bin"]]),
    "fg":    (0x8000, [["b25-12.18f", "b25-12.rom", "12.bin"],
                       ["b25-15.23f", "b25-15.rom", "15.bin"],
                       ["b25-14.21f", "b25-14.rom", "14.bin"],
                       ["b25-13.19f", "b25-13.rom", "13.bin"]]),
    "obj":   (0x10000, [["b25-01.14c", "b25-01.rom", "1.bin"],
                        ["b25-02.16c", "b25-02.rom", "2.bin"],
                        ["b25-03.17c", "b25-03.rom", "3.bin"],
                        ["b25-04.19c", "b25-04.rom", "4.bin"]]),
}
PROMS = ["82s129.b19", "82s129.b18", "82s123.b21", "82s123.c6", "82s123.f1"]

# region starts, mirroring cfg/macros.def
SND_START, DSP_START = 0x040000, 0x048000
CHAR_START, BG_START, FG_START = 0x049000, 0x059000, 0x079000
OBJ_START, PROM_START, TOTAL = 0x099000, 0x0D9000, 0x0D9260


def find(d, names, required=True):
    for n in names:
        p = os.path.join(d, n)
        if os.path.exists(p):
            return open(p, "rb").read()
    if required:
        raise SystemExit("missing ROM, tried: %s" % ", ".join(names))
    return None


def interleave(parts, size):
    """One byte from each plane, plane 0 in the low byte, so a 32-bit read is
    a whole 8-pixel row. Three-plane regions repeat the last plane: the text
    layer's fourth bit is never read."""
    while len(parts) < 4:
        parts.append(parts[-1])
    out = bytearray(size * 4)
    for i in range(size):
        for p in range(4):
            out[i * 4 + p] = parts[p][i]
    return bytes(out)


def build(romdir):
    rom = bytearray(b"\xff" * TOTAL)

    def put(off, data):
        rom[off:off + len(data)] = data

    for off, size, names in MAIN:
        d = find(romdir, names)
        if len(d) != size:
            raise SystemExit("%s: %d bytes, expected %d" % (names[0], len(d), size))
        put(off, d)
    put(SND_START, find(romdir, SND))

    # the DSP mask ROM. MAME's region is ROM_REGION16_BE, and jtframe loads
    # 16-bit words little endian, so the byte pairs are swapped here.
    #
    # Which dump is used matters and is worth saying out loud. The parent set's
    # single file is the Flying Shark MCU, which MAME substitutes because no
    # genuine Wardner DSP has ever been read - it is BAD_DUMP in every Wardner
    # set. The bootleg PROMs are a direct dump of the DSP on a Wardner board.
    # The two agree on 1534 of 1536 words; see ver/dsp/README.md.
    dsp = find(romdir, DSP, required=False)
    if dsp is None:
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "dsp"))
        import dsp_from_proms
        dsp = bytes(dsp_from_proms.build(romdir))[:0xc00]
        print("DSP: rebuilt from the bootleg nibble PROMs (a Wardner board's own)")
    else:
        print("DSP: %s from the parent set (the Flying Shark MCU MAME substitutes)"
              % DSP[0])
    dsp = dsp[:0xc00]                              # the part the mask ROM holds
    swapped = bytearray(len(dsp))
    swapped[0::2] = dsp[1::2]
    swapped[1::2] = dsp[0::2]
    # Everything above 0xc00 stays at the image's 0xff fill, which is what
    # jtframe's MRA generator pads regions with (fill_upto emits " FF").
    put(DSP_START, bytes(swapped))

    for name, start in (("chars", CHAR_START), ("bg", BG_START),
                        ("fg", FG_START), ("obj", OBJ_START)):
        size, cands = PLANES[name]
        parts = []
        for c in cands:
            d = find(romdir, c)
            if len(d) != size:
                raise SystemExit("%s: %d bytes, expected %d" % (c[0], len(d), size))
            parts.append(d)
        put(start, interleave(parts, size))

    off = PROM_START
    for n in PROMS:
        d = find(romdir, [n], required=False)
        if d is None:
            print("warning: PROM %s missing, left as FF" % n)
            continue
        put(off, d)
        off += len(d)
    return bytes(rom)


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    romdir = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "wardner.rom"
    rom = build(romdir)
    with open(out, "wb") as f:
        f.write(rom)
    print("%s: %d bytes (0x%X), crc32 %08x" % (out, len(rom), len(rom), zlib.crc32(rom)))
    for label, start in (("main", 0), ("snd", SND_START), ("dsp", DSP_START),
                         ("char", CHAR_START), ("bg", BG_START),
                         ("fg", FG_START), ("obj", OBJ_START), ("proms", PROM_START)):
        print("  %-6s 0x%06X  %s" % (label, start, rom[start:start + 8].hex()))


if __name__ == "__main__":
    main()
