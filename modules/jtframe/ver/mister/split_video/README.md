# MiSTer split video routing

Run `simunit.sh --run modules/jtframe/ver/mister/split_video`.

The initializer extracts the production routing blocks from `jtframe_emu.sv`
and `sys_top.v`. The test compiles those exact blocks in legacy, split and
split-plus-interlace configurations, checking distinct RGB, sync, DE, CE and
field tags, direct-video switching, legacy scaler/framebuffer options and
split analog overrides. It also exercises the actual `vga_out` RGB/component
converter and guards downstream OSD, field, format and scandoubler connections.

This is a wiring regression. Physical HDMI/CRT output, OSD readability and
monitor-specific sync acceptance require hardware validation. The complete
MiSTer builds cover full top-level elaboration and fitting.
