#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prepare an Avengers MCU replay: prepare.py TRACE ROM.

ROM is either av.13k (4096 bytes) or the generated avengers.rom. No ROM
bytes are checked into the repository. Run from the test's working folder.
"""
import sys
from pathlib import Path

trace, rom = map(Path, sys.argv[1:])
image = rom.read_bytes()
if len(image) != 4096:
    image = image[16 + 0xC8000:16 + 0xC9000]
if len(image) != 4096:
    raise SystemExit('Expected av.13k or a generated avengers.rom')
# Confirmed bad opcode in the MCU dump; also patched by MAME and the MRA.
image = bytearray(image)
image[0xB84] = 0x02
Path('mcu.hex').write_text(''.join(f'{byte:02x}\n' for byte in image))

rows = []
for line in trace.read_text().splitlines():
    timestamp, kind, address, data = line.split()
    rows.append((round(float(timestamp) * 1e9), kind, int(address, 16), int(data, 16)))
events, expected, pending = [], [], []
p0 = p2 = p3 = 255
for time, kind, address, data in rows:
    if kind == 'W':
        if pending and time - pending[-1][0] >= 30000:
            events.extend((t, 1, d) for t, d in pending)
            pending = []
        pending.append((time, data))
    elif kind == 'I' and address == 0x90:
        # P1 selects sound versus angle commands. Hold the captured video
        # count throughout that request, independent of compressed idle gaps.
        if pending:
            events.append((pending[0][0] - 1, 4, data))
    elif kind == 'S':
        events.append((time, 2, data))
    elif kind == 'R':
        events.append((time, 3, data))
    elif kind == 'O':
        if address == 0x80:
            p0 = data
        elif address == 0xA0:
            p2 = data
        elif address == 0xB0:
            if data & 64 and not p3 & 64:
                expected.append((p0, p2))
                # Keep service time intact even when no main read follows
                # an angle/sound response. Only idle gaps may be shortened.
                events.append((time, 6, 0))
            p3 = data

events.extend((t, 1, d) for t, d in pending)
writes = [(t, d) for t, kind, d in events if kind == 1]
for time, data in writes:
    # The full core produces separate one-T-state write strobes, not a
    # continuous interrupt across the seven repeated LD instructions.
    events.append((time + 167, 5, 0))
if not expected or not writes:
    raise SystemExit('Trace has no MCU requests or latched responses')
events.sort()
previous = elapsed = 0
with Path('events.txt').open('w') as output:
    for time, kind, data in events:
        gap = time - previous
        elapsed += 100000 if gap > 1000000 else gap
        previous = time
        output.write(f'{elapsed} {kind} {data}\n')
Path('expected.txt').write_text(''.join(f'{a:02x} {b:02x}\n' for a, b in expected))
Path('counts.vh').write_text(f'localparam EXPECTED_COUNT = {len(expected)};\n')
print(f'Replaying {len(writes)} main writes, {len(expected)} MCU latches in {elapsed / 1e9:.3f}s')
