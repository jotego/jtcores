# JTDCASTL, FPGA hardware compatible with Universal's Do's Castle board family

One core covering nine officially released games on three related Universal
hardware profiles. A single MRA per game selects its profile at load time
through the ROM header, so all nine share one RBF.

| MAME set | Game | Profile | Rotation |
|---|---|---|---|
| docastle | Mr. Do's Castle | Castle | vertical (ccw) |
| douni | Mr. Do! vs. Unicorns | Castle | vertical (ccw) |
| dorunrun | Do! Run Run | Run Run | horizontal |
| dowild | Mr. Do's Wild Ride | Run Run | horizontal |
| jjack | Jumping Jack | Run Run | vertical (ccw) |
| kickridr | Kick Rider | Run Run | horizontal |
| spiero | Super Pierrot | Run Run | horizontal |
| idsoccer | Indoor Soccer | Soccer | horizontal |
| asoccer | American Soccer | Soccer | horizontal |

The board runs three 4 MHz Z80s (main, sub/sound, and a sprite CPU), four
SN76489A PSGs, an HD6845S CRTC, and — on the Soccer profile only — an MSM5205
ADPCM channel. Sprite support comes from Universal's custom CF37201N.

# Hardware evidence

This core is built from primary hardware sources rather than emulator
behaviour alone:

- **Universal's service manual schematics**, for the CPU maps, CRTC wiring,
  watchdog, tile/sprite priority encoding, colour-PROM addressing and the RGB
  resistor weights.
- **Furrtek's CF37201N (TAL004) decap reproduction**, for the custom chip's
  register decode (A3 is not decoded), X/Y counters, palette/flip latches, the
  two-phase DRAM address mux, serial inversion, field parity, and the measured
  126-MCLK `/PL` interrupt cycle.

MAME's `universal/docastle.cpp` is used as a cross-check only. Where it and the
hardware evidence disagree, the RTL follows the hardware.

Points worth noting versus emulation:

- Three real Z80s, not one CPU timeshared. The cycle-sensitive main/sub WAIT
  handshake is modelled rather than approximated in software; it is
  asymmetric, only the main CPU stalls.
- The sprite CPU's ROM actually executes instead of being bypassed. Its
  `0xc000`-`0xc7ff` writes into the CF37201 doorway drive the real sprite
  hardware path. The `0x8000` staging-RAM phase is modelled for CPU-bus
  accuracy but, per real-hardware/decap evidence, never feeds the displayed
  sprite output on real PCBs — only the optional CF37201 framebuffer
  renderer (off by default) consumes it.
- The CRTC exposes writable R0-R15 with frame-shadowed register writes, so a
  programming burst in progress cannot commit a broken timing mode mid-frame —
  a failure the schematic's own CURSOR-interrupt wiring can otherwise trigger.
- 312 x 264 total raster, 240 x 192 visible, HD6845S at 9.828 MHz / 16, pixel
  clock 9.828 MHz / 2, giving the authentic ~59.659 Hz refresh.
- The four PSGs use real READY-driven wait states rather than fire-and-forget
  writes.
- The colour PROM is a weighted resistor DAC with an asymmetric 3/3/2 bit split
  (RRRGGGBB). `JTFRAME_COLORW=4` with the 8-bit weighted sums truncated at
  `[7:4]` keeps every channel exact and monotonic.

# Known limitations

- The tile and sprite renderers (`hdl/jtdcastl_video.v`) are hand-rolled, not
  built on `jtframe_tilemap`/`jtframe_objdraw`. Investigated and deliberately
  not adopted: both generic modules require bit-planar ROM data, but this
  board's real, decap-verified gfx ROMs are nibble-packed (2 pixels/byte) --
  a genuine hardware format mismatch, not a naming one (same situation as
  `cores/kicker/hdl/jtkicker_objdraw.v`, which hand-decodes its own ROM
  format for the same reason). `jtframe_obj_buffer`'s registered BRAM read
  would also add real latency this repo has no pixel-diff harness to verify.
  See the comment block above `line0_even` in jtdcastl_video.v for the full
  reasoning.
- No `ver/` scenes yet, so nothing here has been compared frame by frame.
- The optional CF37201 framebuffer renderer (`hdl/jtdcastl_pcb_sprite.v`) is
  not the default and has never been checked against a physical PCB; the
  direct sprite renderer is the one used.
- Never elaborated by Quartus and never run on hardware.
- No physical board has been available, so none of the accuracy work above has
  been confirmed against one.


# Credits

Ported from the standalone MiSTer Universal_DoCastle core. SN76489A (jt89) and
MSM5205 (jt5205) implementations are Jose Tejada's. `jt89` is carried in
`hdl/` because there is no `modules/jt89` submodule upstream; `jt5205` is used
as the existing submodule.
