#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""PPM (P3/P6) to PNG, optionally scaled up by an integer factor, no PIL.
usage: ppm2png.py <in.ppm> <out.png> [scale]"""
import sys, zlib, struct
sys.path.insert(0, __import__("os").path.dirname(__file__))
from diff_ppm import read_ppm

def png(w, h, rgb, path):
    raw = b"".join(b"\0" + rgb[y*w*3:(y+1)*w*3] for y in range(h))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))

w, h, px = read_ppm(sys.argv[1])
s = int(sys.argv[3]) if len(sys.argv) > 3 else 1
if s > 1:
    rows = [px[y*w*3:(y+1)*w*3] for y in range(h)]
    rows = [b"".join(r[x*3:x*3+3] * s for x in range(w)) for r in rows]
    px = b"".join(r for r in rows for _ in range(s)); w, h = w*s, h*s
png(w, h, px, sys.argv[2])
