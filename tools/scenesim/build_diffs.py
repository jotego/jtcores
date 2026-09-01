#!/usr/bin/env python3
"""
Build per-scene "MAME / diff / FPGA" stacked PNGs for a core.

Usage:
    build_diffs.py <core> [setname] [--rot {90,180,270}]

For VERTICAL cores (ROT90/ROT270, e.g. vaportra) the MAME screen.png is the
raw landscape raster while the FPGA frame is already rotated to portrait. Pass
--rot to rotate the MAME reference into the FPGA orientation before diffing
(vaportra is ROT270 -> --rot 270). If --rot is omitted but the MAME and FPGA
aspect orientations disagree, the tool auto-applies 270 and prints a note.

Reads:
    cores/<core>/ver/<setname>/scenes/<scene>/screen.png      (MAME ground truth)
    cores/<core>/ver/<setname>/sim_results/<scene>.png        (FPGA sim output;
                                                               .jpg accepted as fallback)

Writes:
    cores/<core>/ver/<setname>/sim_results/diffs/<scene>_compare.png

Each output is three frames stacked vertically with no gap:
    MAME    on top
    diff    middle  -- highlights POSITION mismatches (edge XOR in red)
    FPGA    bottom

The diff uses an edge mask (FIND_EDGES + threshold) so small color/tone
differences don't flood the picture -- only spatial mismatches show up.
"""

from __future__ import annotations
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageOps, ImageFilter

EDGE_THRESHOLD = 30          # FIND_EDGES output above this counts as "edge"
LOGICAL_W, LOGICAL_H = 384, 240   # fallback only; the MAME PNG's native size wins

def normalize(img: Image.Image, size=(LOGICAL_W, LOGICAL_H)) -> Image.Image:
    # NEAREST only — these are integer-pixel arcade frames. Any interpolating
    # filter (LANCZOS/BILINEAR) rings halos around every edge and destroys the
    # pixel-exactness we are trying to compare.
    if img.size != size:
        img = img.resize(size, Image.NEAREST)
    return img.convert("RGB")

# PIL .rotate() is counter-clockwise; MAME ROT270 = 90 deg CCW, ROT90 = 270 CCW.
def rotate_mame(img: Image.Image, rot: int) -> Image.Image:
    if rot == 90:
        return img.transpose(Image.ROTATE_270)   # MAME ROT90  (270 CCW)
    if rot == 180:
        return img.transpose(Image.ROTATE_180)
    if rot == 270:
        return img.transpose(Image.ROTATE_90)     # MAME ROT270 (90 CCW)
    return img

def edge_mask(img: Image.Image) -> Image.Image:
    g = img.convert("L").filter(ImageFilter.FIND_EDGES)
    return g.point(lambda p: 255 if p > EDGE_THRESHOLD else 0, "L")

def make_diff(mame: Image.Image, fpga: Image.Image) -> Image.Image:
    em = edge_mask(mame)
    ef = edge_mask(fpga)
    diff_mask = ImageChops.difference(em, ef)
    # Dim MAME for the diff background so the user sees what scene it is.
    bg = ImageOps.autocontrast(mame.convert("RGB"))
    bg = Image.eval(bg, lambda v: v // 3)
    red = Image.new("RGB", mame.size, (255, 60, 60))
    return Image.composite(red, bg, diff_mask)

def stack(mame: Image.Image, diff: Image.Image, fpga: Image.Image) -> Image.Image:
    w, h = mame.size
    out = Image.new("RGB", (w, h * 3))
    out.paste(mame, (0, 0))
    out.paste(diff, (0, h))
    out.paste(fpga, (0, h * 2))
    return out

def main(argv):
    if len(argv) < 2:
        print("Usage: build_diffs.py <core> [setname]", file=sys.stderr)
        return 1
    rot = None
    pos = []
    for a in argv[1:]:
        if a.startswith("--rot"):
            rot = int(a.split("=", 1)[1]) if "=" in a else "PENDING"
        elif rot == "PENDING":
            rot = int(a)
        else:
            pos.append(a)
    if rot == "PENDING":
        rot = 270
    core = pos[0]
    setname = pos[1] if len(pos) > 1 else core

    here = Path(__file__).resolve().parent
    jtroot = here.parent.parent
    scenes = jtroot / "cores" / core / "ver" / setname / "scenes"
    sims = jtroot / "cores" / core / "ver" / setname / "sim_results"
    out_dir = sims / "diffs"
    out_dir.mkdir(parents=True, exist_ok=True)

    pairs = []
    for png in sorted(scenes.glob("*/screen.png")):
        scene = png.parent.name
        # Prefer the lossless PNG result; fall back to legacy .jpg.
        fpga = sims / f"{scene}.png"
        if not fpga.exists():
            fpga = sims / f"{scene}.jpg"
        if fpga.exists():
            pairs.append((scene, png, fpga))

    if not pairs:
        print(f"No matching scene/sim pairs under {scenes} + {sims}", file=sys.stderr)
        return 1

    print(f"Building {len(pairs)} compare PNGs -> {out_dir}")
    for scene, mame_path, fpga_path in pairs:
        # Compare at the FPGA's NATIVE resolution (the sim emits a 2x-logical
        # frame). NEVER downscale the FPGA -- that resamples away the pixels
        # under test and rings halos around every edge. Keep the FPGA 1:1 and
        # integer-scale the MAME reference UP to match with NEAREST (lossless).
        # Zooming is the viewer's job.
        mame = Image.open(mame_path).convert("RGB")
        fpga = Image.open(fpga_path).convert("RGB")
        # Auto-detect orientation mismatch (landscape MAME vs portrait FPGA).
        eff_rot = rot
        if eff_rot is None:
            mame_land = mame.size[0] >= mame.size[1]
            fpga_port = fpga.size[0] < fpga.size[1]
            if mame_land and fpga_port:
                eff_rot = 270
                print(f"  [auto] {scene}: MAME landscape + FPGA portrait -> --rot 270")
        if eff_rot:
            mame = rotate_mame(mame, eff_rot)
        # bring MAME up to the FPGA grid (NEAREST = integer-double for 2x cores)
        if mame.size != fpga.size:
            mame = normalize(mame, fpga.size)
        stacked = stack(mame, make_diff(mame, fpga), fpga)
        stacked.save(out_dir / f"{scene}_compare.png")
        print(f"  {scene}_compare.png")

    print(f"Done. {len(pairs)} PNGs in {out_dir}")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
