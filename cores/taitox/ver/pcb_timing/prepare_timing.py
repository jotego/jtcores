#!/usr/bin/env python3
"""Overlay the timing CPU image into the generated Superman MRA ROM."""
from pathlib import Path
import os

HERE = Path(__file__).resolve().parent
source = Path(os.environ["ROM"]) / "superman.rom"
data = bytearray(source.read_bytes())
cpu = (HERE / "timing_cpu.bin").read_bytes()
assert len(cpu) == 0x40000
assert len(data) >= 0x10 + 0x90000

# JTFRAME's 16-bit reverse mapping stores each CPU word's bytes in reverse.
mapped = bytearray(cpu)
mapped[0::2], mapped[1::2] = mapped[1::2], mapped[0::2]
data[0x10:0x10 + len(mapped)] = mapped
(HERE / "rom.bin").write_bytes(data)
print(f"Overlay timing image {len(cpu):#x} bytes at MRA maincpu offset 0x10 from {source}")
