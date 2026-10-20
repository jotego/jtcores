#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 20-10-2026

import importlib.util
from pathlib import Path
import struct

spec = importlib.util.spec_from_file_location('video_oracle', Path(__file__).with_name('video-oracle.py'))
oracle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oracle)
folder = Path(__file__).resolve().parents[1] / 'roundup5/road-unit'
folder.mkdir(exist_ok=True)
controls = [0] * 2048
steps = [0, 128, 512, 2048, 4096, 65535]
shifts = [-32768, -3200, -1200, 0, 1270, 32767]
for bank in range(2):
    for y in range(256):
        base = bank * 1024 + y * 4
        step = steps[(y + bank) % len(steps)]
        controls[base] = shifts[(y // 2 + bank) % len(shifts)] & 65535
        controls[base + 1] = (step >> 8) | ((step & 255) << 8)
        controls[base + 2] = shifts[(y // 3 + bank + 2) % len(shifts)] & 65535
pixels = [(i * 7 + i // 5) & 15 for i in range(2048)]
colors = [(i * 37 + 85) & 255 for i in range(2048)]
for name, values in [('controls', controls), ('pixels', pixels), ('colors', colors)]:
    (folder / (name + '.hex')).write_text(''.join(f'{v:04x}\n' for v in values))
blocks = dict(road_ctrl_ram=struct.pack('<2048H', *controls), road_pixel_ram=struct.pack('<2048H', *pixels),
              road_color_ram=struct.pack('<2048H', *colors), road_yclip=struct.pack('<H', 19))
for bank in range(2):
    blocks['road_vregs'] = struct.pack('<H', bank * 16)
    rows = oracle.road_lines(blocks, [0, 1, 0, 0, 0, 200 << 8, 0, 0])
    values = [(512 | row[x]) if row else 0 for row in rows for x in range(320)]
    (folder / f'expected{bank}.hex').write_text(''.join(f'{v:03x}\n' for v in values))
