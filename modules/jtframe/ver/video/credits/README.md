# Credits renderer simulation

The simunit runs the same black-box pixel oracle with `PAGES=1`, `3`, and `5`.
`init.go` generates five pages with page-specific glyphs, tile-row/column
palettes, and asymmetric glyph bits so page selection, coordinates, and bit
orientation are observable.

The oracle checks every output pixel against integer `floor(dest * 256 / extent)`
coordinate mapping. Coverage includes horizontal active widths 384,
320, 256, 240, and 512; rotations 01 and 11 at active heights 224 and 240;
four-pixel-clock RGB/sync alignment; a slower pixel enable with two master
clock gaps; a VB fall coincident with HB rising; scroll at a page seam, the
last visible row, the fully blank endpoint, and the wrap to page zero; page-0
CPU read/write; row-7 VRAM dim sideband behavior; enable restart after a
sampled low followed by a high during a pixel-enable gap; and disabled RGB
passthrough with varying nonzero input colors.
