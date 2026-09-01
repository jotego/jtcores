#!/usr/bin/env python3
"""
Zoom a rectangular slice of MAME and FPGA outputs for the same scene,
overlay a pixel grid in magenta so individual pixels are countable, and
stack them MAME-on-top / FPGA-on-bottom.

Usage:
    zoom_slice.py <core> <scene> [options]

Options:
    --x X0       slice left edge (default: center the slice horizontally)
    --y Y0       slice top edge  (default: 0)
    --w  W       slice width  in original pixels (default: 48)
    --h  H       slice height in original pixels (default: 120)
    --zoom Z     integer zoom factor (default: 9)
    --setname S  override MAME setname (default: same as core)
    --output P   override output PNG path

Output (default):
    cores/<core>/ver/<setname>/sim_results/<scene>_zoom_<X0>_<Y0>_<W>x<H>_<Z>x.png
"""

from __future__ import annotations
import argparse, sys
from pathlib import Path
from PIL import Image, ImageDraw

MAGENTA = (255, 0, 255)

def normalize(img: Image.Image, size) -> Image.Image:
    # NEAREST keeps the result pixel-exact (the FPGA frame is usually an
    # integer multiple of the MAME logical size, so this is a clean N:1
    # downsample with no smoothing — important for counting pixel offsets).
    if img.size != size:
        img = img.resize(size, Image.NEAREST)
    return img.convert("RGB")

def zoom_and_grid(crop: Image.Image, zoom: int, grid: int = 1) -> Image.Image:
    # grid = grid-line spacing in SOURCE pixels (1 = per-pixel; 8 = tile grid
    # for 8x8-tile identification, 16 for 16x16 tiles).
    zw, zh = crop.size[0] * zoom, crop.size[1] * zoom
    big = crop.resize((zw, zh), Image.NEAREST)
    d = ImageDraw.Draw(big)
    step = zoom * max(grid, 1)
    for x in range(0, zw + 1, step):
        d.line([(x, 0), (x, zh - 1)], fill=MAGENTA)
    for y in range(0, zh + 1, step):
        d.line([(0, y), (zw - 1, y)], fill=MAGENTA)
    return big

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("core")
    ap.add_argument("scene")
    ap.add_argument("--x", type=int, default=None)
    ap.add_argument("--y", type=int, default=0)
    ap.add_argument("--w", type=int, default=48)
    ap.add_argument("--h", type=int, default=120)
    ap.add_argument("--zoom", type=int, default=9)
    ap.add_argument("--grid", type=int, default=1,
                    help="grid-line spacing in source pixels (8 = 8x8-tile grid)")
    ap.add_argument("--setname", default=None)
    ap.add_argument("--output", default=None)
    args = ap.parse_args()

    setname = args.setname or args.core
    here = Path(__file__).resolve().parent
    jtroot = here.parent.parent
    scene_dir = jtroot / "cores" / args.core / "ver" / setname / "scenes" / args.scene
    sim_dir = jtroot / "cores" / args.core / "ver" / setname / "sim_results"
    mame_path = scene_dir / "screen.png"
    # Prefer the lossless PNG result; fall back to legacy .jpg.
    fpga_path = sim_dir / f"{args.scene}.png"
    if not fpga_path.exists():
        fpga_path = sim_dir / f"{args.scene}.jpg"

    for p in (mame_path, fpga_path):
        if not p.exists():
            print(f"Missing: {p}", file=sys.stderr)
            return 1

    # The MAME screen.png defines the logical resolution (320x224 for taitob,
    # 384x240 for superman, ...). The FPGA frame is scaled to match it.
    mame_img = Image.open(mame_path)
    logical = mame_img.size
    W, H = logical
    x0 = args.x if args.x is not None else max(0, (W - args.w) // 2)
    y0 = args.y
    if x0 + args.w > W or y0 + args.h > H:
        print(f"Slice {args.w}x{args.h} @ ({x0},{y0}) exceeds frame {W}x{H}", file=sys.stderr)
        return 1

    box = (x0, y0, x0 + args.w, y0 + args.h)
    mame_crop = normalize(mame_img, logical).crop(box)
    fpga_crop = normalize(Image.open(fpga_path), logical).crop(box)

    mame_big = zoom_and_grid(mame_crop, args.zoom, args.grid)
    fpga_big = zoom_and_grid(fpga_crop, args.zoom, args.grid)
    w, h = mame_big.size
    out = Image.new("RGB", (w, h * 2))
    out.paste(mame_big, (0, 0))
    out.paste(fpga_big, (0, h))

    if args.output:
        out_path = Path(args.output)
    else:
        out_path = sim_dir / f"{args.scene}_zoom_{x0}_{y0}_{args.w}x{args.h}_{args.zoom}x.png"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(out_path)
    print(f"Saved {out_path}  ({out.size[0]}x{out.size[1]})")
    return 0

if __name__ == "__main__":
    sys.exit(main())
