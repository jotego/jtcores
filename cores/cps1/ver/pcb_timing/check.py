#!/usr/bin/env python3
"""Check the V14 result pages rendered by jtsim against frames.ref.

Each line of frames.ref is "<page> <first> <last> <crc32>": the last PNG
written in frames/ with a number in [first, last] must exist, show more than
one colour and its raw RGBA pixels must have that CRC-32. jtsim only writes a
PNG when the image changes, so the last PNG of the window is the stable page.
"""
from pathlib import Path
import re
import sys
import zlib
from PIL import Image

here = Path(__file__).resolve().parent
frames = {int(m.group(1)): p for p in (here / 'frames').glob('frame_*.png')
          if (m := re.fullmatch(r'frame_(\d+)\.png', p.name))}
update = '--update' in sys.argv
ref = here / 'frames.ref'
lines, errors = [], 0
for line in ref.read_text().splitlines():
    if not line.strip() or line.startswith('#'):
        lines.append(line)
        continue
    page, first, last, crc = line.split()
    inside = [n for n in frames if int(first) <= n <= int(last)]
    if not inside:
        print(f'FAIL page {page}: no frame in {first}..{last}')
        errors += 1
        lines.append(line)
        continue
    img = Image.open(frames[max(inside)]).convert('RGBA')
    got = f'{zlib.crc32(img.tobytes()):08x}'
    colours = len(set(img.getdata()))
    if colours < 2:
        print(f'FAIL page {page}: frame {max(inside)} is blank')
        errors += 1
    elif got != crc and not update:
        print(f'FAIL page {page}: frame {max(inside)} CRC {got}, expected {crc}')
        errors += 1
    else:
        print(f'ok   page {page}: frame {max(inside)} CRC {got}')
    lines.append(f'{page} {first} {last} {got}')
if update:
    ref.write_text('\n'.join(lines) + '\n')
print('FAIL' if errors else 'PASS')
sys.exit(1 if errors else 0)
