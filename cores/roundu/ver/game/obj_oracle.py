#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 19-10-2026

import json
from pathlib import Path
import struct


def render(roms, ram, bank):
    image = [0] * (320 * 240)
    for offset in range(bank * 0x1000, bank * 0x1000 + 0x800, 6):
        index, flags, x, y, scale, rotate = ram[offset:offset + 6]
        if index == 65535 or scale == 65535:
            break
        if index >= 0x4000 or not (scale & 511):
            continue
        scale &= 511
        x, y = ((v + 32768) % 65536 - 32768 for v in (x, y))
        flip_x, flip_y = bool(flags & 0x8000), bool(flags & 0x4000)
        slope = ((rotate + 256) % 512 - 256) * (-1 if flip_x else 1)
        shrink = (1 << 40) // (65536 + slope * slope)
        header = roms[0][index * 4:index * 4 + 4]
        top = header[0] & 248
        rows = (header[2] + ((header[3] & 1) << 8) - top + 7) // 8
        if rows <= 0:
            continue
        runs = []
        for row in range(rows):
            bank_index, address = (0, index + 1 + row // 2) if row & 1 else (1, index + row // 2)
            width, left, base = struct.unpack_from('<BBH', roms[bank_index], address * 4)
            runs.append((left * 8, (left + width + 1) * 8, base * 2))
        width = max(right for left, right, base in runs)
        scaled_top = top * scale // 128
        scaled_bottom = (top * scale + rows * 8 * scale + 127) // 128
        scaled_right = (width * scale + 127) // 128
        corners = []
        for corner in range(4):
            cx = scaled_right if corner & 1 else 0
            cy = scaled_bottom if corner & 2 else scaled_top
            if flip_x:
                cx = -cx
            if flip_y:
                cy = -cy
            corners.append((cx * 256 - slope * cy, slope * cx + cy * 256))
        xmin = max(0, x + min(cx for cx, cy in corners) // 256 - 1)
        xmax = min(319, x - (-max(cx for cx, cy in corners) // 256) + 1)
        ymin = max(0, y + min(cy for cx, cy in corners) // 256 - 1)
        ymax = min(239, y - (-max(cy for cx, cy in corners) // 256) + 1)
        if header[3] & 128:
            xmin, xmax, ymin, ymax = 0, 319, 0, 239
        for py in range(ymin, ymax + 1):
            dy = (py - y) * 65536 + 32768
            for px in range(xmin, xmax + 1):
                dx = (px - x) * 65536 + 32768
                ux = ((dx + ((slope * dy) >> 8)) * shrink) >> 40
                uy = ((dy - ((slope * dx) >> 8)) * shrink) >> 40
                if flip_x:
                    ux = -ux - 1
                if flip_y:
                    uy = -uy - 1
                if ux < 0 or uy < 0:
                    continue
                line, column = uy * 128 // scale, ux * 128 // scale
                if not top <= line < top + rows * 8:
                    continue
                left, right, base = runs[(line - top) // 8]
                if column < left:
                    continue
                if column >= right:
                    if not header[3] & 128:
                        continue
                    column = left + (column - left) % (right - left)
                tile = base + (column - left) // 8
                bits = [8, 12, 0, 4, 24, 28, 16, 20][column & 7]
                byte = roms[tile & 1][((tile // 2) % 24576) * 32 + (line & 7) * 4 + bits // 8]
                pen = (byte >> (4 if bits % 8 == 0 else 0)) & 15
                if not pen:
                    continue
                clut = ((flags >> 3) % 256) * 16 + pen
                color = roms[(clut >> 2) & 1][0xbf800 + (clut >> 3) * 4 + ((clut & 3) ^ 1)]
                pos = py * 320 + px
                image[pos] = (image[pos] & 511) | 512 if color == 255 else 256 | color
    return image


def main():
    target = Path(__file__).resolve().parents[1] / 'roundup5/obj-unit'
    target.mkdir(exist_ok=True)
    roms = [bytearray(0xc0000), bytearray(0xc0000)]
    for bank, rom in enumerate(roms):
        for tile in range(0x200, 0x400):
            for y in range(8):
                for x in range(8):
                    pen = (tile * 3 + y * 5 + x * 7 + bank * 2) & 15
                    bits = [8, 12, 0, 4, 24, 28, 16, 20][x]
                    address = tile * 32 + y * 4 + bits // 8
                    rom[address] |= pen << (4 if bits % 8 == 0 else 0)
        for group in range(512):
            for lane in range(4):
                entry = group * 8 + bank * 4 + lane
                value = (entry * 7 + 13) % 255
                if entry // 16 == 3 and entry % 16 in (2, 7, 11):
                    value = 255
                rom[0xbf800 + group * 4 + (lane ^ 1)] = value
    ram = [0] * 8192
    cases = [(12, 16, 128, 0, 0), (96, 16, 128, 0x8008, 0),
             (128, 52, 128, 0x4010, 0), (184, 52, 128, 0xc018, 0),
             (12, 76, 64, 0, 0), (62, 76, 192, 8, 0), (145, 76, 255, 16, 0),
             (40, 125, 128, 0, 64), (100, 140, 144, 8, 416),
             (190, 125, 128, 0x8010, 64), (225, 140, 128, 0x4018, 480),
             (8, 200, 128, 8, 0), (240, 16, 128, 16, 0), (240, 16, 128, 24, 0),
             (-8, 220, 511, 0, 0), (290, -8, 65, 8, 0), (280, -400, 128, 0, 0)]
    for number, (x, y, scale, flags, rotate) in enumerate(cases):
        index = 0x100 + number * 8
        top, lines, repeat = (8, 24, 128) if number == 11 else (0, 16, 0)
        if number == 16:
            lines, repeat = 255, 1
        roms[0][index * 4:index * 4 + 4] = bytes((top, 0, lines, repeat))
        for row in range(64 if number == 16 else 2):
            address = index + (row // 2) + (1 if row & 1 else 0)
            bank = 0 if row & 1 else 1
            struct.pack_into('<BBH', roms[bank], address * 4, 0 if number == 16 else 1 + row, 0 if number == 16 else row, 0x200 + (number * 8 + row * 4) % 256)
        for bank in range(2):
            location = bank * 0x1000 + number * 6
            ram[location:location + 6] = [index, flags, (x + bank * 5) & 65535, y & 65535, scale, rotate]
    for bank in range(2):
        end = bank * 0x1000 + len(cases) * 6
        ram[end] = 65535
    for bank, rom in enumerate(roms):
        (target / f'obj-rom-{bank}.bin').write_bytes(rom)
        expected = render(roms, ram, bank)
        (target / f'expected-{bank}.hex').write_text(''.join(f'{v:03x}\n' for v in expected))
    (target / 'objram.hex').write_text(''.join(f'{v:04x}\n' for v in ram))
    (target / 'vectors.json').write_text(json.dumps(dict(cases=cases, scope='inverse affine equations from current MAME driver; both RAM banks, scaling, clipping, flips, row runs, repetition, CLUT/shadow and overlap'), indent=2) + '\n')


if __name__ == '__main__':
    main()
