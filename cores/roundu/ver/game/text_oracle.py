#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 19-10-2026

import argparse
import hashlib
import json
import re
from pathlib import Path
import struct
import zlib


def png(path, data):
    def chunk(kind, value):
        return struct.pack('>I', len(value)) + kind + value + struct.pack('>I', zlib.crc32(kind + value))
    rows = b''.join(b'\0' + data[y * 960:(y + 1) * 960] for y in range(240))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 320, 240, 8, 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


def main():
    core = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument('--scene', default='text600')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    scene = core / 'ver/roundup5/scenes' / args.scene
    raw = (scene / 'dump.bin').read_bytes()
    assert len(raw) == 149568
    log = (scene / 'mame.log').read_text()
    assert 'TEXT_REFERENCE_OK' in log
    mame_source = json.loads((scene / 'mame-source.json').read_text())
    assert mame_source['capture_script_sha256'] == hashlib.sha256((core / 'ver/game/capture_text.lua').read_bytes()).hexdigest()
    assert mame_source['launcher_sha256'] == hashlib.sha256((core / 'ver/game/capture-text.sh').read_bytes()).hexdigest()
    frame = int(re.search(r'TEXT_DUMP_OK frame=(\d+)', log)[1])
    vram, gfx, palette, crtc = raw[:16384], raw[16384:147456], raw[147456:149504], raw[149504:]
    for name, data in [('videoram.bin', vram), ('tx_gfxram.bin', gfx), ('palette.bin', palette)]:
        (scene / name).write_bytes(data)
    scroll = ((((crtc[12] << 8) | crtc[13]) & 0x3fff) >> 4) | crtc[29]
    (scene / 'scroll.hex').write_text(f'{scroll:03x}\n')
    rgb, words = bytearray(), []
    for y in range(240):
        for x in range(320):
            sx, sy = (x + 24) % 1024, (y + scroll) % 512
            offset = ((sy // 8) * 128 + sx // 8) * 2
            attr = int.from_bytes(vram[offset:offset + 2], 'little')
            row = (attr & 4095) * 8 + sy % 8
            pen = sum(((gfx[row + plane * 0x8000] >> (7 - sx % 8)) & 1) << plane for plane in range(3))
            color_index = (attr >> 12) * 8 + pen if pen else 384
            color = int.from_bytes(palette[color_index * 2:color_index * 2 + 2], 'little') & 0x7fff
            words.append(f'{color:04x}\n')
            for shift in (10, 5, 0):
                value = (color >> shift) & 31
                rgb.append((value << 3) | (value >> 2))
    (scene / 'expected.hex').write_text(''.join(words))
    png(scene / 'expected-text.png', rgb)
    report = dict(schema=2, game='roundup5', scope='isolated text-renderer diagnostic; full-board replay not prepared',
                  mame=mame_source,
                  capture_frame=frame, reference_frame=frame + 1, mode='hardware-test' if 'testmode=true' in log else 'normal' if 'testmode=false' in log else 'not-recorded', text_state_held=True,
                  full_board_restore_ready=False, dump_bytes=len(raw),
                  blocks=[dict(name='videoram', size=16384, endian='LE16'), dict(name='tx_gfxram', size=131072, endian='byte'),
                          dict(name='palette', size=2048, endian='LE16 normalized from BE8 palette aperture'),
                          dict(name='crtc', size=64, owner='jtroundu_main.crtc', source='write tap at C000-C003 low byte')],
                  excluded='sprites, road, landscape and their controls are outside this isolated text diagnostic',
                  scroll_y=scroll, source_config_sha256=hashlib.sha256((core / 'cfg/mem.yaml').read_bytes()).hexdigest(),
                  hashes={name: hashlib.sha256((scene / name).read_bytes()).hexdigest()
                          for name in ['dump.bin', 'screen.png', 'videoram.bin', 'tx_gfxram.bin', 'palette.bin', 'scroll.hex']})
    (scene / 'capture.json').write_text(json.dumps(report, indent=2) + '\n')
    if args.check:
        ppm = (scene / 'rtl.ppm').read_bytes().split(b'\n', 3)[3]
        assert ppm == rgb, 'RTL replay pixels differ from the text oracle'
        png(scene / 'rtl-text.png', ppm)
        sources = [core / 'hdl/jtroundu_video.v', core / 'hdl/jtroundu_text.v',
                   * (core.parents[1] / 'modules/jtframe/hdl/video/tilemap').glob('jtframe_*.v'), core / 'ver/hdl/text_scene_tb.v',
                   core / 'ver/game/text_oracle.py', core / 'ver/game/replay-text.sh',
                   core.parents[1] / 'modules/jtframe/hdl/ram/jtframe_dual_ram.v',
                   core.parents[1] / 'modules/jtframe/hdl/ram/jtframe_dual_ram16.v']
        replay = dict(status='pass', scope=report['scope'], compared_pixels=76800, differing_pixels=0,
                      capture_sha256=hashlib.sha256((scene / 'capture.json').read_bytes()).hexdigest(),
                      image_sha256=hashlib.sha256((scene / 'rtl-text.png').read_bytes()).hexdigest(),
                      source_sha256={str(p.relative_to(core.parents[1])): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources})
        (scene / 'text-replay.json').write_text(json.dumps(replay, indent=2) + '\n')
        print('PASS: all 76800 text pixels match the captured-state oracle')


if __name__ == '__main__':
    main()
