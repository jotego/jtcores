#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""Convert jtsim's frame.raw (RGBA, one byte per channel) to PNG.

jtsim normally shells out to ImageMagick's `convert` for this; that tool is
absent in some containers, and this needs nothing but the standard library.

usage: raw2png.py <frame.raw> <out.png> [width] [height] [scale]
"""
import sys, zlib, struct

def png(w, h, rgb, path):
    raw = b"".join(b"\0" + rgb[y * w * 3:(y + 1) * w * 3] for y in range(h))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n"
                + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))

def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    w = int(sys.argv[3]) if len(sys.argv) > 3 else 320
    h = int(sys.argv[4]) if len(sys.argv) > 4 else 240
    s = int(sys.argv[5]) if len(sys.argv) > 5 else 1
    d = open(src, "rb").read()
    if len(d) < w * h * 4:
        raise SystemExit("%s holds %d bytes, need %d for %dx%d RGBA"
                         % (src, len(d), w * h * 4, w, h))
    rgb = bytearray(w * h * 3)
    for i in range(w * h):
        rgb[3 * i:3 * i + 3] = d[4 * i:4 * i + 3]
    if s > 1:
        rows = [bytes(rgb[y * w * 3:(y + 1) * w * 3]) for y in range(h)]
        rows = [b"".join(r[x * 3:x * 3 + 3] * s for x in range(w)) for r in rows]
        rgb = b"".join(r for r in rows for _ in range(s)); w, h = w * s, h * s
    png(w, h, bytes(rgb), dst)
    print("wrote %s (%dx%d)" % (dst, w, h))

if __name__ == "__main__":
    main()
