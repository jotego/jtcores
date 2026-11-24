# S18 colmix passive timing check

This unit sim instantiates production `jts18_colmix`, `jtframe_blank`, `jtframe_sh`, the S16B `jtframe_vtimer`, and the S18 framework output path (`jtframe_short_blank` with crop disabled, then `jtframe_crosshair` with `JTFRAME_LIGHTGUN` enabled and drawing disabled). It runs a fixed 48 MHz clock with synchronous 6 MHz (`pxl_cen`) and 12 MHz (`pxl2_cen`) enables.

Two mixer instances share source blanking. One receives the synthetic YM RGB/YS tuple directly. The candidate-only adapter delays the complete `{YS, RGB}` tuple by three `pxl_cen` events before the production mixer. The tuple source starts H26/ID0 at the helper-observed LHBL rise, then advances once per native H event, matching the issue 180 source edge convention.

The test checks all 320 internal colmix samples and all 320 externally exposed blank samples, including the first and last pixels. It checks the final RGB stream with unique VDP IDs, a static S16 background, alternating YS transparency, and steady selection cases for empty S16 layers, VDP priority over S16 content, S16 disable, and VDP disable.

The three-pixel tuple adapter aligns VDP IDs 0..319 to the colmix's internal delayed RGB window. The full framework output still exposes raw game blanking with a one-pixel framework delay, while RGB passes through the colmix DLY4 window and framework crosshair RGB stage. Consequently this synthetic path has a four-pixel black/cropped edge at the game output: exposed x0..x3 are black, and the final window shows compensated VDP IDs0..315 at x4..x319. The adapter changes the IDs shown within that window but does not align its edges. This test does not prove YM7101 acquisition, renderer content, optional framework crop modes, or changing S16 priority boundaries.
