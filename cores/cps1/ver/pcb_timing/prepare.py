#!/usr/bin/env python3
"""Overlay the V14 68000 image on the CPU portion of an SF2 JTFRAME ROM."""
from pathlib import Path
import os

here = Path(__file__).resolve().parent
source = Path(os.environ['ROM']) / 'sf2ua.rom'
data = bytearray(source.read_bytes())
program = (here / 'firmware.bin').read_bytes()
marker = (here / 'marker.bin').read_bytes()
assert len(program) < 0x20000 and len(marker) == 8
assert len(data) > 64 + 0x40000
cpu = bytearray(b'\xff' * 0x40000)
cpu[:len(program)] = program
cpu[-8:] = marker
# MRA CPU data uses swapped bytes within each 16-bit word.
cpu[0::2], cpu[1::2] = cpu[1::2], cpu[0::2]
data[64:64 + len(cpu)] = cpu
(here / 'rom.bin').write_bytes(data)
