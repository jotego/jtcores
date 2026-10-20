#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 20-10-2026

import hashlib
import json
from pathlib import Path
import re
import yaml

CORE = Path(__file__).resolve().parents[2]
REPO = CORE.parents[1]
SET = CORE / 'ver/roundup5'
REGIONS = [('videoram', 16384), ('tx_gfxram', 131072), ('palette', 2048), ('crtc', 64),
           ('bg_gfxram', 131072), ('spriteram', 16384), ('obj_ctrl_ram', 512),
           ('road_ctrl_ram', 4096), ('road_pixel_ram', 4096), ('road_color_ram', 4096),
           ('road_yclip', 2), ('road_vregs', 2), ('registers', 22)]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def definitions():
    return yaml.safe_load((CORE / 'cfg/mmr.yaml').read_text())


def split(raw):
    assert len(raw) == sum(size for _, size in REGIONS) == 309850
    offset, blocks = 0, {}
    for name, size in REGIONS:
        blocks[name] = raw[offset:offset + size]
        offset += size
    return blocks


def register_blocks(blocks):
    return dict(crtc=blocks['crtc'], main=blocks['registers'] + bytes(10),
                road=blocks['road_yclip'] + blocks['road_vregs'], object=blocks['obj_ctrl_ram'])


def registers(blocks):
    raw = register_blocks(blocks)
    fields, packed = {}, bytearray()
    for block in definitions():
        data = raw[block['name']]
        assert len(data) == block['size']
        packed.extend(data)
        for register in block['regs']:
            value, width = 0, 0
            for chunk in str(register['at']).split(','):
                match = re.fullmatch(r'(\d+)(?:\[(\d+)(?::(\d+))?\])?', chunk)
                assert match, chunk
                byte = int(match[1])
                high = int(match[2]) if match[2] else 7
                low = int(match[3] or match[2]) if match[2] else 0
                bits = high - low + 1
                value = (value << bits) | ((data[byte] >> low) & ((1 << bits) - 1))
                width += bits
            assert width == register['dw']
            fields[block['name'] + '.' + register['name']] = value
    assert len(packed) == 612
    return bytes(packed), fields


def prepare():
    defs = definitions()
    assert [(d['name'], d['size'], d['dw']) for d in defs] == [
        ('crtc', 64, 8), ('main', 32, 16), ('road', 4, 16), ('object', 512, 16)]
    main = (CORE / 'hdl/jtroundu_main.v').read_text()
    sub = (CORE / 'hdl/jtroundu_sub.v').read_text()
    for item in ['reg [15:0] vregs [0:7]', 'reg [7:0] crtc [0:63]',
                 'crtc[12][5:0],crtc[13][7:4]', 'crtc[29]', 'bg_back_x = vregs[6]',
                 'road_enable = vregs[1][0]', 'road_top = vregs[5][15:8]']:
        assert item in main, item
    assert 'output reg [15:0] road_yclip' in sub and 'output reg [15:0] road_vregs' in sub
    memory = yaml.safe_load((CORE / 'cfg/mem.yaml').read_text())
    names = {r['name'] for r in memory['bram']}
    assert {n for n, _ in REGIONS if n.endswith('ram') or n == 'palette'} <= names
    offset, maps = 0, []
    bench = (CORE / 'ver/hdl/video_scene_tb.v').read_text()
    for d in defs:
        generated = CORE / ('hdl/jtroundu_' + d['name'] + '_mmr.v')
        text = generated.read_text()
        assert 'mmr_init' in text and 'parameter SIMFILE=' in text
        assert 'jtroundu_' + d['name'] + '_mmr #(' in bench
        assert 'u_scene_' + d['name'] + ' (' in bench
        assert 'u_scene_' + d['name'] + '.mmr[r]' in bench
        maps.append(dict(name=d['name'], bytes=d['size'], mmr_offset=offset,
                         fields=d['regs'], module=generated.name))
        offset += d['size']
    dependencies = [CORE / 'cfg/mem.yaml', CORE / 'cfg/mmr.yaml', CORE / 'hdl/jtroundu_main.v',
                    CORE / 'hdl/jtroundu_sub.v', CORE / 'ver/hdl/video_scene_tb.v',
                    Path(__file__), CORE / 'ver/game/capture_video.lua']
    report = dict(game='roundup5', dump_bytes=309850, mmr_bytes=612, byte_order='LE16; graphics and CRTC byte-wide',
                  blocks=[dict(name=n, bytes=s) for n, s in REGIONS], mmr_blocks=maps,
                  register_ownership='Live CPU owners remain handwritten; generated MMR instances restore and verify all raw bytes and exported fields in frozen replay',
                  main_padding='bytes22..31 of the main MMR block are deliberate zero padding',
                  excluded='CPU execution/interrupt state, CRTC address index, audio-only registers; all CPU write masters are absent in frozen video replay',
                  dependencies={str(p.relative_to(REPO)): sha(p) for p in dependencies})
    (SET / 'scene-profile.json').write_text(json.dumps(report, indent=2) + '\n')
    return report
