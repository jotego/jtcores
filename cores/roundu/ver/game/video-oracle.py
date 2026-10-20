#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 19-10-2026

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
from PIL import Image
from obj_oracle import render
from text_oracle import png
from scene_contract import CORE, REPO, SET, definitions, registers, sha, split


def road_lines(blocks, vregs):
    control = struct.unpack('<2048H', blocks['road_ctrl_ram'])
    pixels = struct.unpack('<2048H', blocks['road_pixel_ram'])
    colors = struct.unpack('<2048H', blocks['road_color_ram'])
    clip, = struct.unpack('<H', blocks['road_yclip'])
    bank, = struct.unpack('<H', blocks['road_vregs'])
    first_y = 256 - ((vregs[5] >> 8) + clip)
    result = [None] * 240
    if not vregs[1] & 1:
        return result
    def signed(n):
        return (n & 65535) - (65536 if n & 32768 else 0)
    def divide(n, d):
        return abs(n) // d * (-1 if n < 0 else 1)
    for y in range(max(0, first_y), 240):
        base = (1024 if bank & 16 else 0) + y * 4
        shift1, raw_step, shift2, _ = control[base:base + 4]
        step = (raw_step >> 8) | ((raw_step & 255) << 8)
        start1 = divide(-signed(shift1) * 256 + 128, step) if step else 65536
        start2 = divide(-signed(shift1 + shift2) * 256 + 128, step) if step else 65536
        local_y = y - first_y
        palette = 320 + ((colors[(local_y // 8) & 2047] >> (local_y % 8)) & 1) * 16
        row = []
        for x in range(320):
            p1, p2 = (x - start1) * step, (x - start2) * step
            if 0 <= p1 < 128 * 2048:
                address, palette_bank = p1 >> 11, 0
            elif 0 <= p2 < 128 * 2048:
                address, palette_bank = 512 + (p2 >> 11), 32
            elif x < start1 and x < start2:
                address, palette_bank = (512, 32) if start2 < start1 else (0, 0)
            elif x >= start1 and x >= start2:
                address, palette_bank = (127, 0) if start2 < start1 else (639, 32)
            else:
                address, palette_bank = 128, 32
            row.append(palette + palette_bank + (pixels[address] & 15))
        result[y] = row
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--scene', required=True)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--record-sources', action='store_true')
    args = parser.parse_args()
    assert args.scene.isdigit()
    scene = SET / 'scenes' / args.scene
    work = SET / 'scene-work'
    work.mkdir(exist_ok=True)
    suite = json.loads((SET / 'scene-capture.json').read_text())
    entry = next(s for s in suite['scenes'] if s['name'] == args.scene)
    assert all(sha(scene / name) == h for name, h in entry['files'].items())
    for name in ['cores/roundu/cfg/mem.yaml', 'cores/roundu/cfg/mmr.yaml']:
        assert sha(REPO / name) == suite['profile']['dependencies'][name]
    blocks = split((scene / 'dump.bin').read_bytes())
    packed, fields = registers(blocks)
    assert packed == (scene / 'mmr.bin').read_bytes()
    assert fields == entry['registers']
    for name, data in blocks.items():
        (work / (name + '.bin')).write_bytes(data)
    (work / 'mmr.bin').write_bytes(packed)
    ordered = [fields[b['name'] + '.' + r['name']] for b in definitions() for r in b['regs']]
    (work / 'expected-regs.hex').write_text(''.join(f'{v:04x}\n' for v in ordered))
    control, = struct.unpack_from('<H', blocks['registers'])
    vregs = struct.unpack_from('<8H', blocks['registers'], 2)
    scroll_x, scroll_y = struct.unpack_from('<2H', blocks['registers'], 18)
    text_y = fields['crtc.text_base'] | fields['crtc.text_low']
    ctrl = struct.unpack('<256H', blocks['obj_ctrl_ram'])
    ram = struct.unpack('<8192H', blocks['spriteram'])
    rom = (REPO / 'rom/roundup5.rom').read_bytes()
    assert hashlib.md5(rom).hexdigest() == '96d85273c6bbbbedce3063f834fdd0f5'
    roms = [rom[0x100000:0x1c0000], rom[0x1c0000:0x280000]]
    objects = render(roms, ram, bool(ctrl[0xe0] & 0x1000))
    for n, data in enumerate(roms):
        (work / f'obj-rom-{n}.bin').write_bytes(data)
    colors = struct.unpack('<1024H', blocks['palette'])
    tilemap = struct.unpack('<8192H', blocks['videoram'])
    roads = road_lines(blocks, vregs)
    pixels, rgb = [], bytearray()
    for y in range(240):
        for x in range(320):
            obj = objects[y * 320 + x]
            index = 384
            for layer, height, base, sx, delta in [(0, 128, 0x10000, vregs[6], 0), (1, 64, 0x18000, scroll_x, 64)]:
                local_y = y - (384 - (scroll_y & 511) + delta)
                local_x = (x + sx) & 511
                if 0 <= local_y < height:
                    byte = blocks['bg_gfxram'][base + local_y * 256 + local_x // 2]
                    pen = (byte >> (4 if local_x & 1 else 0)) & 15
                    if pen:
                        index = (0x110 if layer == 0 else 0x100) + pen
            if roads[y] is not None:
                index = roads[y][x]
            if obj & 512:
                index += 512
            tx, ty = (x + 24) % 1024, (y + text_y) % 512
            attr = tilemap[(ty // 8) * 128 + tx // 8]
            row = (attr & 4095) * 8 + ty % 8
            text_pen = sum(((blocks['tx_gfxram'][row + plane * 0x8000] >> (7 - tx % 8)) & 1) << plane for plane in range(3))
            text_index = (attr >> 12) * 8 + text_pen
            if control & 128:
                if text_pen:
                    index = text_index
                if obj & 256:
                    index = 512 + (obj & 255)
            else:
                if obj & 256:
                    index = 512 + (obj & 255)
                if text_pen:
                    index = text_index
            color = colors[index] & 32767
            pixels.append(color)
            for shift in (10, 5, 0):
                c = (color >> shift) & 31
                rgb.append((c << 3) | (c >> 2))
    (work / 'expected.hex').write_text(''.join(f'{v:04x}\n' for v in pixels))
    png(work / 'expected.png', rgb)
    paths = [*(CORE / 'hdl' / n for n in ['jtroundu_video.v', 'jtroundu_text.v', 'jtroundu_obj.v', 'jtroundu_bg.v', 'jtroundu_road.v']),
             *CORE.glob('hdl/*_mmr.v'), CORE / 'hdl/jtroundu_main.v', CORE / 'hdl/jtroundu_sub.v',
             CORE / 'cfg/mmr.yaml', CORE / 'cfg/mem.yaml',
             REPO / 'modules/jtframe/hdl/ram/jtframe_obj_buffer.v',
             REPO / 'modules/jtframe/hdl/ram/jtframe_dual_ram.v',
             REPO / 'modules/jtframe/hdl/ram/jtframe_dual_ram16.v',
             *(REPO / 'modules/jtframe/hdl/video/tilemap').glob('jtframe_*.v'),
             CORE / 'ver/hdl/video_scene_tb.v', Path(__file__),
             Path(__file__).with_name('obj_oracle.py'), Path(__file__).with_name('scene_contract.py'),
             Path(__file__).with_name('replay-video.py')]
    provenance = dict(source_sha256={str(p.relative_to(REPO)): sha(p) for p in paths},
                      capture_sha256=hashlib.sha256(json.dumps(entry, sort_keys=True).encode()).hexdigest())
    if args.record_sources:
        (work / 'replay-source.json').write_text(json.dumps(provenance, indent=2) + '\n')
    if args.check:
        assert json.loads((work / 'replay-source.json').read_text()) == provenance, 'Sources/capture changed during replay'
        actual = (work / 'rtl.ppm').read_bytes().split(b'\n', 3)[3]
        assert actual == rgb, 'RTL differs from the combined video oracle'
        image_path = SET / 'sim_results' / (args.scene + '.png')
        png(image_path, actual)
        reference = Image.open(scene / 'screen.png').convert('RGB').tobytes()
        diffs = sum(reference[i:i + 3] != actual[i:i + 3] for i in range(0, len(actual), 3))
        log = (SET / (args.scene + '-replay.log')).read_text()
        assert 'PASS: 612 raw MMR bytes and 16 exported fields restored' in log
        manifest = SET / 'scene-replay.json'
        report = json.loads(manifest.read_text()) if manifest.exists() else dict(scenes={})
        if report.get('source_sha256') != provenance['source_sha256']:
            report = dict(scenes={})
        report.update(status='complete' if len(report['scenes']) + (args.scene not in report['scenes']) == len(suite['scenes']) and suite['status'] == 'complete' else 'partial',
                      source_sha256=provenance['source_sha256'], simulator=json.loads((SET / 'scene-simulator.json').read_text()),
                      raster_master_clocks_per_pixel=32, scanline_timing_verified=False,
                      scope='All captured video RAM and generated MMR state; CPUs absent from frozen testbench')
        report['scenes'][args.scene] = dict(compared_pixels=76800, oracle_differing_pixels=0,
            mame_context_differing_pixels=diffs, mmr_bytes_verified=612, mmr_fields_verified=16,
            capture_sha256=provenance['capture_sha256'], image=str(image_path.relative_to(SET)),
            image_sha256=sha(image_path), reference_sha256=sha(scene / 'screen.png'))
        manifest.write_text(json.dumps(report, indent=2) + '\n')
        print(f'PASS {args.scene}: 612 MMR bytes, 16 fields, 76800 video pixels; MAME0.282 differing pixels={diffs}')


if __name__ == '__main__':
    main()
