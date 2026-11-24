#!/usr/bin/env python3
"""Rebuild the V14 program and reproduce its embedded identity fields."""
from pathlib import Path
import subprocess
import tempfile
import zlib

here = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    def run(*args):
        subprocess.run(args, check=True)
    run('m68k-linux-gnu-as', '-m68000', '--defsym=CASE_COUNT=77', '-o', str(tmp/'asm.o'), str(here/'diagnostic.s'))
    run('m68k-linux-gnu-gcc', '-m68000', '-Os', '-ffreestanding', '-fno-builtin', '-fno-pic', '-fno-stack-protector', '-fno-asynchronous-unwind-tables', '-fno-unwind-tables', '-I', str(here), '-c', '-o', str(tmp/'c.o'), str(here/'firmware.c'))
    run('m68k-linux-gnu-ld', '-T', str(here/'layout.ld'), '-o', str(tmp/'firmware.elf'), str(tmp/'asm.o'), str(tmp/'c.o'))
    run('m68k-linux-gnu-objcopy', '-O', 'binary', str(tmp/'firmware.elf'), str(tmp/'raw.bin'))
    symbols = {}
    for line in subprocess.check_output(['m68k-linux-gnu-nm', '-n', str(tmp/'firmware.elf')], text=True).splitlines():
        fields = line.split()
        if len(fields) == 3:
            symbols[fields[2]] = int(fields[0], 16)
    raw = (tmp/'raw.bin').read_bytes()
    image = bytearray(b'\xff' * 0x40000)
    image[:len(raw)] = raw
    suite = symbols['firmware_suite_crc32']
    image_crc = symbols['firmware_image_crc32']
    assert image[suite:suite+4] == bytes(4) and image[image_crc:image_crc+4] == bytes(4)
    image[suite:suite+4] = bytes.fromhex('9b2bf924')
    image[-8:] = (here/'marker.bin').read_bytes()
    image[image_crc:image_crc+4] = (zlib.crc32(image) & 0xffffffff).to_bytes(4, 'big')
    if image[:len(raw)] != (here/'firmware.bin').read_bytes():
        raise SystemExit('Rebuilt firmware differs from firmware.bin')
    print(f'Rebuilt firmware matches firmware.bin ({len(raw)} bytes)')
