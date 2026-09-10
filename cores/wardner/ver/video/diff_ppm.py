#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""Pixel diff of two PPM files (P3 or P6). Prints the mismatch count, the
first few mismatches and, optionally, writes a P6 image with the differing
pixels in white on a darkened copy of the first image.

usage: diff_ppm.py <a.ppm> <b.ppm> [diff.ppm]"""
import sys

def read_ppm(path):
    d = open(path, "rb").read()
    toks, i = [], 0
    while len(toks) < 4:
        while d[i:i+1].isspace(): i += 1
        if d[i:i+1] == b"#":
            while d[i:i+1] not in (b"\n", b""): i += 1
            continue
        j = i
        while not d[j:j+1].isspace(): j += 1
        toks.append(d[i:j]); i = j
    i += 1
    magic, w, h = toks[0], int(toks[1]), int(toks[2])
    if magic == b"P6":
        px = d[i:i+w*h*3]
    else:
        px = bytes(int(t) for t in d[i:].split())
    return w, h, px

def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    wa, ha, a = read_ppm(sys.argv[1])
    wb, hb, b = read_ppm(sys.argv[2])
    if (wa, ha) != (wb, hb):
        raise SystemExit("size mismatch %dx%d vs %dx%d" % (wa, ha, wb, hb))
    bad = [i for i in range(wa*ha) if a[3*i:3*i+3] != b[3*i:3*i+3]]
    print("%d of %d pixels differ" % (len(bad), wa*ha))
    for i in bad[:10]:
        print("  (%3d,%3d): %s vs %s" % (i % wa, i // wa, a[3*i:3*i+3].hex(), b[3*i:3*i+3].hex()))
    if len(sys.argv) > 3:
        out = bytearray(v // 3 for v in a)
        for i in bad:
            out[3*i:3*i+3] = b"\xff\xff\xff"
        with open(sys.argv[3], "wb") as f:
            f.write(b"P6\n%d %d\n255\n" % (wa, ha)); f.write(out)
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
