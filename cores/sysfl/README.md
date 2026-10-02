# JTSYSFL — Namco System FL

Speed Racer / Final Lap R. Approximate re-implementations of the Namco
customs, each in its own folder under `hdl/`:

| Folder | Chips | Function |
|--------|-------|----------|
| hdl/c123 | 123 + 145 | 4 scroll + 2 fixed tilemaps, 8x8x8bpp, mask ROM |
| hdl/c169 | C169      | 2 ROZ layers, 16x16x8bpp, per-scanline mode (road) |
| hdl/c355 | C355 + 187| zooming sprites, dual-page OBJ RAM, line buffers |
| hdl/c116 | C116 + 156| priority mixer, palette, clip window, raster IRQ |

Main CPU: i960KA (cen-based). Sound/IO: C75 (M37702) + C352. Network (C345)
is stubbed. Reference: MAME namcofl.cpp and device files.

## Video chain contract

All modules: `clk` + `pxl_cen` (6.048 MHz), 384x264 total, 288x224 visible.
Layer outputs to jtc116 mixer:

- c123: `scr_pxl[11:0]` (palette base 0x1000), `scr_prio[2:0]`, blank flag
- c169: `roz_pxl[11:0]` (palette base 0x1800), `roz_prio[3:0]`, blank flag
- c355: `obj_pxl[11:0]` (palette base 0x000), `obj_prio[3:0]`, shadow flag
  (list pen 0xffe), transparent pen = 0xff
- c116: 16-level priority mix per MAME screen_update, 3x8kB palette BRAM,
  programmable clip window, raster IRQ from reg 5

Board memories (VRAMs, OBJ RAM, palette) live in cfg/mem.yaml as BRAM;
chip modules only expose read ports.
