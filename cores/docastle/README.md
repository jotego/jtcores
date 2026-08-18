# JTDOCASTLE, FPGA hardware compatible with Universal's Do's Castle board family

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
- The sprite CPU's ROM actually executes instead of being bypassed. Both
  observed bus phases are implemented: staging RAM into its `0x8000` work
  doorway, and its `0xc000`-`0xc7ff` writes into the CF37201.
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

**Graphics ROM handshake (must be resolved before hardware use).** The tile
and sprite fetch paths were written against a fixed one-cycle BRAM latency and
still ignore `gfx1_ok` / `gfx2_ok`, with `*_cs` tied high. Per
`jtframe_romrq.v`, holding `addr_ok` high is only valid while the address does
not change before `data_ok` — which the sprite state machine breaks, so
fetches can return stale bytes. Note that a bare `ST_GWAIT: if(gfx2_ok)` is
*not* a sufficient fix: with `OKLATCH=1`, `data_ok` remains high for a cycle
after the address changes, so a naive test can pass on a stale `ok`. Either
toggle `gfx2_cs` per request, or gate on a freshly cleared `ok`, and confirm
against a waveform. Moving `gfx1` to BRAM (a fixed 16 kB on all nine sets)
would remove the problem for tiles outright, config-only, but sprites must
stay in SDRAM. See the header of `hdl/jtdocastle_game.v` for the full analysis.

**Not yet simulated.** There are no `ver/` scenes, so nothing here has been
compared frame-by-frame in this form. The core passes `jtframe cfgstr`, `mem`,
`files`, `msg` and `mra`, and lints clean under Verilator (0 errors, 0
warnings) with the top at `jtdocastle_game_sdram`, but it has not been
elaborated by Quartus and has not run on hardware.

**Optional CF37201 framebuffer renderer.** `hdl/jtdocastle_pcb_sprite.v`
implements the decap-derived alternating-field framebuffer. It is not the
default and has never been confirmed against a physical PCB; the direct sprite
renderer is the one used.

**No physical board.** None of the above has been checked against real Do's
Castle hardware, as no board has been available.

# Credits

Ported from the standalone MiSTer Universal_DoCastle core. SN76489A (jt89) and
MSM5205 (jt5205) implementations are Jose Tejada's. `jt89` is carried in
`hdl/` because there is no `modules/jt89` submodule upstream; `jt5205` is used
as the existing submodule.
