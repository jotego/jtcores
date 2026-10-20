#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 18-10-2026

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET
import zipfile
import zlib


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--archive', type=Path, required=True)
    args = parser.parse_args()
    game = Path(__file__).resolve().parent
    core = game.parent.parent
    repo = core.parent.parent
    target = core / 'ver/roundup5'
    roms = target / 'roms'
    extracted = roms / 'extracted'
    extracted.mkdir(parents=True, exist_ok=True)
    archive = args.archive.expanduser().resolve()
    contract_path = core / 'cfg/rom_layout.json'
    contract = json.loads(contract_path.read_text())
    files = {op['file']: op for region in contract['regions']
             for op in region['operations'] if op['kind'] == 'load'}
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as source:
            if set(source.namelist()) != set(files):
                raise ValueError('Archive members differ from the exact set')
            for name in files:
                (extracted / name).write_bytes(source.read(name))
    else:
        members = subprocess.check_output(['/usr/bin/tar', '-tf', str(archive)], text=True).splitlines()
        if set(members) != set(files):
            raise ValueError('Archive members differ from the exact set')
        subprocess.run(['/usr/bin/tar', '-xf', str(archive), '-C', str(extracted)], check=True)
    derived = roms / 'roundup5.zip'
    if archive == derived.resolve():
        raise ValueError('Choose the original archive outside the temporary ZIP path')
    rows = []
    with zipfile.ZipFile(derived, 'w', compression=zipfile.ZIP_STORED) as output:
        for name, op in files.items():
            data = (extracted / name).read_bytes()
            crc = f'{zlib.crc32(data) & 0xffffffff:08x}'
            sha1 = hashlib.sha1(data).hexdigest()
            if len(data) != op['length'] or crc != op['crc32'] or sha1 != op['sha1']:
                raise ValueError(f'Physical ROM mismatch: {name}')
            output.writestr(name, data)
            rows.append(dict(name=name, size=len(data), crc32=crc, sha1=sha1))
    (target / 'archive-verification.json').write_text(json.dumps(dict(
        source_archive=str(archive), source_sha256=sha256(archive),
        derived_zip_sha256=sha256(derived), files_checked=len(rows),
        files=rows, status='pass'), indent=2) + '\n')
    env = os.environ.copy()
    env.update(JTROOT=str(repo), JTFRAME=str(repo / 'modules/jtframe'),
               CORES=str(repo / 'cores'), JTBIN=str(repo / 'release'))
    helper = repo / 'modules/jtframe/bin/jtframemac'
    with (target / 'mra-generation.log').open('w') as log:
        subprocess.run([str(helper), 'mra', 'roundu', '--path', str(roms), '--skipPocket'],
                       env=env, cwd=repo, stdout=log, stderr=subprocess.STDOUT, check=True)
    rom = repo / 'rom/roundup5.rom'
    if rom.stat().st_size != 0x2d0000:
        raise ValueError('Incorrect assembled ROM size')
    mra = repo / 'release/mra/Round Up 5 - Super Delta Force.mra'
    assembled_md5 = ET.parse(mra).getroot().find("rom[@index='0']").attrib['asm_md5']
    if assembled_md5 != hashlib.md5(rom.read_bytes()).hexdigest():
        raise ValueError('MRA assembled MD5 differs from the generated stream')
    subprocess.run(['ruby', str(game / 'verify_layout.rb')], check=True)
    with (game / 'mem-generation.log').open('w') as log:
        subprocess.run([str(helper), 'mem', 'roundu', '--target', 'mister', '--local', '--inc'],
                       env=env, cwd=game, stdout=log, stderr=subprocess.STDOUT, check=True)
    with (game / 'defines.f').open('w') as out:
        subprocess.run([str(helper), 'cfgstr', 'roundu', '--target', 'mister', '--output', 'iverilog'],
                       env=env, cwd=game, stdout=out, check=True)
    with (target / 'download-build.log').open('w') as log:
        subprocess.run(['iverilog', '-g2012', '-s', 'rom_download_tb', '-c', 'defines.f',
                        '-I', '.', '-I', str(repo / 'modules/jtframe/hdl/inc'),
                        '-o', str(target / 'rom_download.vvp'), 'rom_download_tb.v',
                        str(core / 'hdl/jtroundu_download.v'),
                        str(repo / 'modules/jtframe/hdl/sdram/jtframe_dwnld.v')],
                       cwd=game, stdout=log, stderr=subprocess.STDOUT, check=True)
    with (target / 'download.log').open('w') as log:
        subprocess.run(['vvp', str(target / 'rom_download.vvp'), f'+ROM={rom}'],
                       cwd=target, stdout=log, stderr=subprocess.STDOUT, check=True)
    banks = []
    bank_rows = []
    for bank, size in enumerate((0x100000, 0xc0000, 0xc0000, 0x50000)):
        path = target / f'sdram_bank{bank}.bin'
        raw = path.read_bytes()
        if len(raw) != size:
            raise ValueError(f'Incorrect bank {bank} size')
        normal = bytearray(raw)
        normal[0::2], normal[1::2] = raw[1::2], raw[0::2]
        banks.append(normal)
        bank_rows.append(dict(bank=bank, size=size, dump_sha256=sha256(path),
                              logical_sha256=hashlib.sha256(normal).hexdigest()))
    actual = b''.join(banks)
    expected = bytearray(rom.read_bytes())
    expected[0x2c0000:0x2d0000] = bytes(0x10000)
    if actual != expected:
        first = next(i for i, (a, b) in enumerate(zip(actual, expected)) if a != b)
        raise ValueError(f'Downloaded bank mismatch at {first:#x}')
    downloaded = target / 'downloaded.mame.rom'
    downloaded.write_bytes(actual)
    offsets = dict(master_rom=0, slave_rom=0x80000, audiocpu=0x280000,
                   **{'sprites:sprites_l': 0x100000, 'sprites:sprites_h': 0x1c0000, 'oki': 0x290000})
    regions = []
    verifier = repo / '.claude/skills/jtcore-start/scripts/rom_layout.rb'
    for index, region in enumerate(contract['regions']):
        name = region['name']
        report = target / f'region-{index}.json'
        command = ['ruby', str(verifier), 'verify', '--contract', str(contract_path),
                   '--region', name, '--zip', str(derived), '--actual', str(downloaded),
                   '--offset', hex(offsets[name]), '--report', str(report)]
        if name == 'oki':
            command += ['--hole-fill', '0']
        subprocess.run(command, check=True)
        regions.append(json.loads(report.read_text()))
    result = dict(status='pass', game='roundup5', physical_files_checked=len(rows),
                  compared_bytes=len(actual), regions=regions, banks=bank_rows,
                  source_archive=str(archive), source_archive_sha256=sha256(archive),
                  contract_sha256=sha256(contract_path), rom_stream_sha256=sha256(rom),
                  assembled_md5=assembled_md5,
                  mra_sha256=sha256(mra), mem_config_sha256=sha256(core / 'cfg/mem.yaml'),
                  loader_hdl_sha256=sha256(core / 'hdl/jtroundu_download.v'),
                  testbench_sha256=sha256(game / 'rom_download_tb.v'),
                  downloaded_logical_sha256=sha256(downloaded),
                  bank_dump_serialization='big-endian 16-bit words; byte-swapped to logical addresses for comparison',
                  download_scope='actual JTFRAME downloader and game adapter with a bank-write model; no CPU execution',
                  padding='MRA FF converted to MAME zero in the final 65536 OKI bytes',
                  cpu_boot_observed=False)
    (target / 'rom-verification.json').write_text(json.dumps(result, indent=2) + '\n')
    layout_path = core / 'cfg/rom_layout_fpga.json'
    layout = json.loads(layout_path.read_text())
    layout.update(actual_rom_bytes_verified=True,
                  rom_verification_report='../ver/roundup5/rom-verification.json',
                  downloaded_bank_bytes_verified=True,
                  download_scope=result['download_scope'])
    layout_path.write_text(json.dumps(layout, indent=2) + '\n')
    derived.unlink()
    print(f'PASS: 27 physical ROMs, six complete logical regions, four downloaded banks, {len(actual)} bytes')


if __name__ == '__main__':
    main()
