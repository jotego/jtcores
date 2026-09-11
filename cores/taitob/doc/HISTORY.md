# taitob — HISTORY

Per-commit decisions + dead ends. Newest at the bottom.

## 2026-05-26 — Bootstrap

Started the Taito B System core, first target Rastan Saga 2 / Nastar.

### Why Superman as the template (not Rastan)

The repo has two Taito 68k cores already:

- **rastan** (Taito original Rastan, 1987) — older PC080SN/PC090OJ
  video board + YM2151 + MSM5205 + PC060HA. Different sound chips,
  different video chips, different sound-comms chip. Zero overlap.
- **superman** (Taito X System, 1988) — Seta-built board sold by
  Taito. Same 68000 + Z80 + YM2610 + TC0140SYT as Taito B. Different
  video chips (Seta X1-001A) and a C-chip protection MCU.

Superman wins because the CPU spine and sound subsystem are bit-for-bit
the same chips Taito B uses. Cloning Superman drops in the entire
CPU+sound+SYT plumbing for free; the only real work is the video chip.

### What was inherited vs written fresh

| Module                | Source                                |
|-----------------------|---------------------------------------|
| `jttaitob_syt.v`      | verbatim copy of `jtsuperman_syt.v`   |
| `jttaitob_snd.v`      | derived from `jtsuperman_snd.v`       |
| `jttaitob_main.v`     | new (different memory map)            |
| `jttaitob_ioc.v`      | new (Superman uses C-chip, not IOC)   |
| `jttaitob_video.v`    | new stub (no reference exists)        |
| `jttaitob_colmix.v`   | new (trivial palette → RGB wire)      |
| `jttaitob_game.v`     | derived from `jtsuperman_game.v`      |

### Clock pick: PXLCLK=8

Real chip is 27.164 MHz / 4 ≈ 6.79 MHz pixel clock. Not a clean divisor
of our 48 MHz frame clock. The framework only supports PXLCLK=6 or 8.
At PXLCLK=6 the H rate (~14.4 kHz) lands below the 15.625 kHz NTSC
target that MiSTer's HDMI scaler and analog CRTs expect — produces bad
vertical stripes on HDMI and CRT refuses to sync (this is the Superman
precedent, see cores/superman/cfg/macros.def lines 51–63).

Picked PXLCLK=8 with H_total=512, V_total=260 → 60.10 Hz refresh,
H rate 15.625 kHz. Within 0.2% of MAME's 60.000 Hz nominal.

### TC0260DAR — no module exists in MAME

The TC0260DAR is a passive 12-bit RGBx_444 palette DAC. MAME doesn't
emulate it as a device — it just declares a generic `palette_device`
with `RGBx_444` format (taito_b.cpp:1887). So `jttaitob_colmix.v` is
literally a wire from the 12-bit palette word to {R[3:0], G[3:0], B[3:0]}.
Saved a chip on the BOM, saved a Verilog file.

### Why the framebuffer region is a black hole

`tc0180vcu_memrw` maps 0x40000-0x7FFFF inside the VCU window as a
framebuffer used by Hit The Ice for its pixel-bitmap mode and Realpunc
for its camera overlay. Rastan Saga 2 doesn't touch this region.
Allocating 256 KB of BRAM (or backing it with SDRAM) for a feature no
Phase A game uses is wasteful — `fb_cs` is decoded but discarded.
Re-enable when hitice / realpunc land in this bitstream.

### What's deliberately deferred

- **TC0220IOC**: real coin counter / lockout output not wired (the
  framework's `coin` input does the work). The stub captures the
  68k's writes into a register the game can read back, which is all
  the Phase A game needs.
- **TC0180VCU**: only the chip-select decode and ctrl-register-byte-0/1
  latching are real; everything else (tile fetch, sprite engine,
  scroll FIFO, priority mixer) is TBD.
- **IRQ 2**: only IRQ 4 (vblank-driven) fires. Real VCU drives both
  inth → IRQ 4 and intl → IRQ 2; the IRQ 2 ISR sets a flag the IRQ 4
  ISR checks (taito_b.cpp:44). Worth re-checking once the boot trace
  is captured — if rastsag2 hangs in the IRQ 4 handler waiting for the
  flag, that's the cause.
- **ADPCM-B**: B81-01.1 (Delta-T voice samples) — present in the ROM
  set but not wired to jt10 yet because mem.yaml doesn't expose an
  `adpcmb` SDRAM bus. Sound effects work; voice clips don't.
