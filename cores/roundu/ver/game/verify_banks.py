#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 19-10-2026

import argparse
import hashlib
import json
from pathlib import Path


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--folder', type=Path)
    args = parser.parse_args()
    core = Path(__file__).resolve().parents[2]
    folder = args.folder or core / 'ver/roundup5'
    layout_path = core / 'cfg/rom_layout_fpga.json'
    layout = json.loads(layout_path.read_text())
    rom_path = core.parents[1] / 'rom/roundup5.rom'
    expected = bytearray(rom_path.read_bytes())
    if len(expected) != layout['rom_stream_size']:
        raise ValueError('Incorrect ROM stream size')
    verified = json.loads((folder / 'rom-verification.json').read_text())
    checks = {
        'rom_stream_sha256': rom_path,
        'mem_config_sha256': core / 'cfg/mem.yaml',
        'loader_hdl_sha256': core / 'hdl/jtroundu_download.v',
        'contract_sha256': core / 'cfg/rom_layout.json',
    }
    if verified['status'] != 'pass' or any(verified[key] != sha256(path) for key, path in checks.items()):
        raise ValueError('ROM verification is stale; rerun verify_roms.py')
    for pad in layout['padding']:
        start = pad['stream_start']
        expected[start:start + pad['size']] = bytes([pad['downloaded_byte']]) * pad['size']
    banks = {}
    rows = []
    for region in layout['regions']:
        bank = region['sdram_bank']
        if bank not in banks:
            path = folder / f'sdram_bank{bank}.bin'
            data = bytearray(path.read_bytes())
            data[0::2], data[1::2] = data[1::2], data[0::2]
            base = min(r['stream_start'] for r in layout['regions'] if r['sdram_bank'] == bank)
            banks[bank] = data, base, path
        data, base, path = banks[bank]
        start, size = region['stream_start'], region['size']
        actual = data[start - base:start - base + size]
        reference = expected[start:start + size]
        if len(actual) != size:
            raise ValueError(f'Short bank dump: {path}')
        differences = sum(a != b for a, b in zip(actual, reference))
        rows.append(dict(name=region['name'], bytes=size, differences=differences))
    report = dict(status='pass' if all(r['differences'] == 0 for r in rows) else 'fail',
                  rom_sha256=sha256(rom_path), layout_sha256=sha256(layout_path),
                  serialization='BE16 dump swapped to logical byte order',
                  banks=[dict(bank=b, dump_bytes=p.stat().st_size, sha256=sha256(p))
                         for b, (_, _, p) in sorted(banks.items())], regions=rows)
    (folder / 'bank-verification.json').write_text(json.dumps(report, indent=2) + '\n')
    if report['status'] != 'pass':
        raise ValueError('Downloaded bank bytes differ')
    print(f"PASS: four SDRAM banks, six regions, {sum(r['bytes'] for r in rows)} bytes")


if __name__ == '__main__':
    main()
