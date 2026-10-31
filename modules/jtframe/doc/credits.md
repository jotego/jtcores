# Credits Screen

The shared credits screen is enabled with `JTFRAME_CREDITS`. Release builds
enable it automatically when `cfg/msg` exists. The file contains 32-character
rows; blank rows count as rows. `jtframe msg <core>` encodes each row as 32
characters and writes one 1024-entry page per `msgN.bin` file (`msg0.bin`,
`msg1.bin`, and so on). `JTFRAME_CREDITS_PAGES` is derived from the number of
rows in `cfg/msg`, with one page as the minimum. Do not set it in
`cfg/macros.def`. The maximum is 16 pages. If a core has no `cfg/msg`, the
macro keeps its default value of three.

Text is converted to character codes with a two-bit palette value:

Escape | Meaning
-------|--------
`\R`  | Red (palette index 0)
`\G`  | Green (palette index 1)
`\B`  | Blue (palette index 2)
`\W`  | White (palette index 3)
`\D`  | Current date
`\C`  | Current commit

The renderer measures the active width and height from the blanking signals.
In horizontal orientation, a 256-pixel credits image is centered when it fits;
narrower active widths scale the image down to fit. In rotated orientations,
the 256-pixel cross-axis scales down to shorter measured active heights,
including common 224- and 240-line modes. The scroll covers all generated
pages, shows a fully blank endpoint at `PAGES*256`, then restarts from page
zero on the next scroll step. Page RAM allocation matches the generated page
count.

The credits RGB and HB/VB/HS/VS outputs have a shared four-`pxl_cen`-tick
latency so the overlay remains aligned with the game image and sync signals.
