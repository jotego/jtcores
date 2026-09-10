#!/usr/bin/env python3
"""
Compare an unflipped render against a flipped one, for screen-flip validation.

Usage: flip_diff.py <flip0.png> <flip1.png> <compare.png>

Screen flip has an exact definition that needs no external reference: for a
static scene the flipped render must be the unflipped render rotated 180
degrees, pixel for pixel. MAME cannot arbitrate this - pspikes.cpp is flagged
MACHINE_NO_COCKTAIL - so this invariant is the specification.

test.cpp rotates the frame -90 instead of +90 when dip_flip is set
(verilator/test.cpp:940), which cancels the core's own 180 degree flip. So the
two saved PNGs must be identical as they are, with no rotation applied here.

The output matches build_diffs.py's presentation, three frames stacked:
    unflipped        on top
    edge-XOR diff    middle (position mismatches in red)
    flipped          bottom

Exit status 0 on a pixel-exact match, 1 otherwise. On failure the best whole
picture shift is reported, which reads off directly as the missing constant.
"""

import sys
import numpy as np
from PIL import Image, ImageChops, ImageOps, ImageFilter

EDGE_THRESHOLD = 30


def edge_mask(img):
    g = img.convert("L").filter(ImageFilter.FIND_EDGES)
    return g.point(lambda p: 255 if p > EDGE_THRESHOLD else 0, "L")


def make_diff(ref, cand):
    dm = ImageChops.difference(edge_mask(ref), edge_mask(cand))
    bg = Image.eval(ImageOps.autocontrast(ref.convert("RGB")), lambda v: v // 3)
    return Image.composite(Image.new("RGB", ref.size, (255, 60, 60)), bg, dm)


def main(argv):
    a = Image.open(argv[1]).convert("RGB")
    b = Image.open(argv[2]).convert("RGB")
    if a.size != b.size:
        print("  SIZE MISMATCH %s vs %s" % (a.size, b.size))
        return 1

    w, h = a.size
    out = Image.new("RGB", (w, h * 3))
    out.paste(a, (0, 0))
    out.paste(make_diff(a, b), (0, h))
    out.paste(b, (0, h * 2))
    out.save(argv[3])

    d = ImageChops.difference(a, b)
    if d.getbbox() is None:
        print("  PASS - flipped render matches the unflipped one")
        return 0

    # The frame is stored rotated for a vertical core: image height is the
    # scanline direction (screen X), image width is the line index (screen Y).
    # Brute force on exact-pixel matches - phase correlation maximises
    # correlation, which is not the same thing and picks spurious peaks here.
    na = np.asarray(a, np.int16)
    nb = np.asarray(b, np.int16)
    best = None
    for dy in range(-32, 33):
        rb = np.roll(nb, dy, 0)
        for dx in range(-32, 33):
            k = int((np.abs(na - np.roll(rb, dx, 1)).sum(axis=2) > 0).sum())
            if best is None or k < best[0]:
                best = (k, dy, dx)
    resid, dy, dx = best
    n = int((np.asarray(d).sum(axis=2) > 0).sum())
    print("  FAIL - %d/%d px differ" % (n, w * h))
    print("  best shift: %d px along the scanline (screen X), %d across (screen Y)"
          % (dy, dx))
    print("  %d px still differ after that shift" % resid)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
