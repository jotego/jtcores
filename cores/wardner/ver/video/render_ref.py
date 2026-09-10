#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reference frame renderer for the Wardner video hardware.

A transcription of MAME 0.289's twincobr_v.cpp screen_update, toaplan_scu.cpp
draw_sprites_common, and the parts of tilemap.cpp / drawgfxt.ipp they lean on,
applied to a snapshot of video memory. It exists to be diffed against the RTL
pixel for pixel, the same way ref32010.c is diffed against the DSP.

Everything below that is not obvious from the game hardware is a documented
MAME behaviour, checked against source rather than recalled:

  * A tilemap with scrolldx=-55, scrolldy=-30 shows pixmap column
    (screen_x + 55 + scrollx) mod width at screen column screen_x.
    (tilemap.cpp effective_rowscroll: value = dx - scroll; the pixmap's
    column 0 lands at screen x = value.)
  * Screen flip sets TILEMAP_FLIPX|TILEMAP_FLIPY on all three tilemaps
    (twincobr_v.cpp flipscreen_w). In tilemap.cpp that mirrors the whole
    pixmap - mappings_update swaps tile positions end to end, tile_update
    XORs each tile's own flip bits - and switches to the second scroll
    offsets, set_scrolldx(-55, -134) / set_scrolldy(-30, -243), through
    effective_rowscroll's flipped branch:
        value = screen_extent - map_size - (dx_flipped - scroll)
    Sampling the unflipped pixmap at (W-1-px, H-1-py) folds the mirror and
    the offset into one coordinate, and the map size cancels:
        flipped   x = (453 + scrollx - screen_x) mod W
                  y = (482 + scrolly - screen_y) mod H
        unflipped x = (55 + scrollx + screen_x) mod W
                  y = (30 + scrolly + screen_y) mod H
    with screen_extent 320 x 240 (visarea.right()+left()+1).
  * Sprites are NOT flipped: the SCU device never reads the screen flip,
    only each sprite's own flipx/flipy attribute bits, and flipscreen_w
    touches the tilemaps alone. This is MAME's behaviour and is reproduced
    here so the diff stays meaningful; whether the real board flips its
    sprites too is unverified.
  * Each tilemap ORs its priority code into a per-pixel value: bg 1, fg 2,
    text 4. (tilemap.cpp scanline_draw_*: pri = (pri & 0xff) | code.)
  * A sprite pixel is suppressed where (1 << pri) & pmask is non-zero, with
    GFX_PMASK_2 = 0xcccc selecting the fg bit and GFX_PMASK_4 = 0xf0f0 the
    text bit. Every non-transparent sprite pixel then sets pri = 31, drawn or
    not, after which no later sprite is ever blocked there.
    (drawgfxt.ipp PIXEL_OP_REMAP_TRANSPEN_PRIORITY.)
  * Sprites are drawn from the last entry to the first, so entry 0 ends up on
    top. Priority 0 sprites are skipped outright; a Y field of 0x100 hides.

usage: render_ref.py <snapshot dir> <gfx dir> <out.ppm> [--no-pri31]
"""
import sys, os

W, H = 320, 240
PMASK_2, PMASK_4 = 0xcccc, 0xf0f0

def words(path, n):
    v = [int(l, 16) for l in open(path) if l.strip()]
    if len(v) < n:
        raise SystemExit("%s: %d words, expected %d" % (path, len(v), n))
    return v[:n]

def regs(path):
    r = {}
    for l in open(path):
        if "=" in l:
            k, v = l.split("=", 1)
            r[k.strip()] = int(v.strip(), 0)
    return r

class Gfx:
    """RGN_FRAC plane-separated tiles: plane p is the p-th slice of the region,
    one bit per pixel, MSB first, `rowbytes` bytes per row."""
    def __init__(self, data, planes, size):
        self.d, self.planes, self.size = data, planes, size
        self.rowbytes = size // 8
        self.tilebytes = self.rowbytes * size
        self.quarter = len(data) // planes
        self.count = self.quarter // self.tilebytes
    def pixel(self, n, y, x):
        n %= self.count                       # drawgfx wraps code % total
        v = 0
        base = n * self.tilebytes + y * self.rowbytes + (x >> 3)
        bit = 7 - (x & 7)
        for p in range(self.planes):
            # MAME lists planeoffset from the most significant bit down, so
            # slice p of the region is pen bit planes-1-p, not bit p
            v |= ((self.d[p * self.quarter + base] >> bit) & 1) << (self.planes - 1 - p)
        return v

def pal_rgb(e):
    r, g, b = e & 0x1f, (e >> 5) & 0x1f, (e >> 10) & 0x1f   # xBGR_555
    x5 = lambda v: (v << 3) | (v >> 2)
    return (x5(r), x5(g), x5(b))

def render(snap, gfxdir, pri31=True):
    tx  = words(os.path.join(snap, "snap_tx.hex"),  0x0800)
    bg  = words(os.path.join(snap, "snap_bg.hex"),  0x2000)
    fg  = words(os.path.join(snap, "snap_fg.hex"),  0x1000)
    pal = words(os.path.join(snap, "snap_pal.hex"), 0x0800)
    obj = words(os.path.join(snap, "snap_obj.hex"), 0x0800)
    r   = regs(os.path.join(snap, "snap_regs.txt"))

    gchar = Gfx(open(os.path.join(gfxdir, "gfx_chars.bin"), "rb").read(), 3, 8)
    gfg   = Gfx(open(os.path.join(gfxdir, "gfx_fg.bin"),    "rb").read(), 4, 8)
    gbg   = Gfx(open(os.path.join(gfxdir, "gfx_bg.bin"),    "rb").read(), 4, 8)
    gobj  = Gfx(open(os.path.join(gfxdir, "gfx_obj.bin"),   "rb").read(), 4, 16)

    palrgb = [pal_rgb(e) for e in pal]
    out = [[(0, 0, 0)] * W for _ in range(H)]
    if not r.get("video_on", 1):
        return out
    pri = [[0] * W for _ in range(H)]

    flip = r.get("flip", 0)

    def coord(sx, sy, scrx, scry, w, h):
        """Pixmap column and row shown at screen (sx, sy)."""
        if flip:
            return (453 + scrx - sx) % w, (482 + scry - sy) % h
        return (55 + scrx + sx) % w, (30 + scry + sy) % h

    bg_bank = 0x1000 if r.get("bg_bank", 0) else 0
    fg_bank = 0x1000 if r.get("fg_bank", 0) else 0

    # ---- background: opaque, priority code 1
    for sy in range(H):
        for sx in range(W):
            px, py = coord(sx, sy, r["bg_scrx"], r["bg_scry"], 512, 512)
            row = (py >> 3) * 64
            code = bg[row + (px >> 3) + bg_bank]
            pix = gbg.pixel(code & 0xfff, py & 7, px & 7)
            out[sy][sx] = palrgb[1024 + ((code >> 12) << 4) + pix]
            pri[sy][sx] = 1

    # ---- foreground: pen 0 transparent, priority code 2
    for sy in range(H):
        for sx in range(W):
            px, py = coord(sx, sy, r["fg_scrx"], r["fg_scry"], 512, 512)
            row = (py >> 3) * 64
            code = fg[row + (px >> 3)]
            pix = gfg.pixel((code & 0xfff) | fg_bank, py & 7, px & 7)
            if pix:
                out[sy][sx] = palrgb[1280 + ((code >> 12) << 4) + pix]
                pri[sy][sx] |= 2

    # ---- text: 64x32 map, pen 0 transparent, priority code 4
    for sy in range(H):
        for sx in range(W):
            px, py = coord(sx, sy, r["tx_scrx"], r["tx_scry"], 512, 256)
            row = (py >> 3) * 64
            code = tx[row + (px >> 3)]
            pix = gchar.pixel(code & 0x7ff, py & 7, px & 7)
            if pix:
                out[sy][sx] = palrgb[1536 + ((code >> 11) << 3) + pix]
                pri[sy][sx] |= 4

    # ---- sprites, last entry first
    for offs in range(0x800 - 4, -1, -4):
        attr = obj[offs + 1]
        prio = (attr >> 10) & 3
        if prio == 0:
            continue
        sy = obj[offs + 3] >> 7
        if sy == 0x100:
            continue
        code  = obj[offs] & 0x7ff
        color = attr & 0x3f
        pmask = {1: PMASK_2 | PMASK_4, 2: PMASK_4, 3: 0}[prio]
        sx = obj[offs + 2] >> 7
        flipx = (attr >> 8) & 1
        flipy = (attr >> 9) & 1
        if flipx:
            sx -= 14
        x0, y0 = sx - 32, sy - 16
        for yy in range(16):
            Y = y0 + yy
            if Y < 0 or Y >= H:
                continue
            srcy = 15 - yy if flipy else yy
            for xx in range(16):
                X = x0 + xx
                if X < 0 or X >= W:
                    continue
                srcx = 15 - xx if flipx else xx
                pix = gobj.pixel(code, srcy, srcx)
                if pix == 0:
                    continue
                if ((1 << pri[Y][X]) & pmask) == 0:
                    out[Y][X] = palrgb[(color << 4) + pix]
                if pri31:
                    pri[Y][X] = 31
    return out

def write_ppm(img, path):
    with open(path, "wb") as f:
        f.write(b"P6\n%d %d\n255\n" % (W, H))
        for row in img:
            f.write(bytes(c for px in row for c in px))

def main():
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)
    img = render(sys.argv[1], sys.argv[2], pri31="--no-pri31" not in sys.argv)
    write_ppm(img, sys.argv[3])
    print("wrote %s" % sys.argv[3])

if __name__ == "__main__":
    main()
