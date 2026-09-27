# DDR ROM controller: a `ddr:` section for mem.yaml

Standalone jtframe proposal: serve selected ROM buses from the MiSTer DDR3
(HPS DDRAM) instead of SDRAM, through the same slot contract cores already
use. Self-contained future PR; no dependency on any core branch work. sysfl
appears only as the motivating case study and likely first adopter.

## Motivation (sysfl numbers)

- A 32MB set fills all four SDRAM banks; the sprite ROM alone owns an 8MB
  bank (objrom, BA1). Every bank freed removes one competitor from the
  arbiter and returns address space.
- DDR bandwidth is idle capital: the f2h port moves 64-bit words in
  128-beat bursts (1kB per burst) while the SDRAM moves 16-bit words.
- ROM download is slow (minutes-feeling): see the root-cause finding below;
  DDR-resident buses skip the SDRAM programming pass entirely.

## Verified plumbing (all cited against the tree)

- The core sees ONE DDR port: `emu` exposes `DDRAM_*` (29-bit 64-bit-word
  address, burstcnt, rd/we/be, dout_ready) —
  target/mister/hdl/jtframe_emu.sv:144-153. Inside jtframe it is shared by
  exactly two clients through a mux: the ROM loader and the video client
  (rotation or line frame buffer) — jtframe_mr_ddrmux.v:5-84, instantiated
  at jtframe_mister.sv:1069. The MiSTer scaler (ascal) uses its own port in
  sys_top, not this one; contention with the scaler happens inside the HPS
  DDR controller, not at this mux.
- THE STAGED COPY: with `JTFRAME_MR_DDRLOAD`, the MRA `<rom>` node carries
  `address="0x30000000"` (mra/corerom.go:215-217) and the MiSTer firmware
  uploads the whole .rom image straight into DDR at 0x3000_0000. The FPGA
  loader detects that no byte-wise ioctl writes arrived (`wr_latch`,
  jtframe_mister_dwnld.v:191-203), then reads the image back in 1kB bursts
  (`ddram_addr = {4'd3, page, 0}`, burstcnt 128 —
  jtframe_mister_dwnld.v:212-218) and plays it byte-serially into the
  `prog_*` SDRAM path. Bytes stream LSB-first from each 64-bit word, i.e.
  the DDR image is the .rom file byte-for-byte, little-endian packed.
  A `ddr:` bus therefore needs NO loader of its own: the pristine .rom
  already sits at 0x3000_0000 + rom_offset when the game starts.
- ROOT CAUSE OF THE SLOW DOWNLOAD (found while verifying, fix is
  independent of this proposal): `jtframe mra` generates MRAs with
  `Target="mist"` (cmd/mra.go:34), so a `JTFRAME_MR_DDRLOAD` kept in the
  `[mister]` section of macros.def is NOT set during MRA generation and
  the `address="0x30000000"` attribute is never emitted (verified absent
  in the generated sysfl MRAs). The firmware then falls back to byte-wise
  ioctl upload and the FPGA re-serializes it at a few clocks per byte.
  Moving the macro to the global section (its other consumers are
  MiSTer-only files) enables the fast path and, incidentally, is a
  precondition for this whole proposal: no address attribute, no staged
  copy.
- STAGED-IMAGE LIFETIME: nothing in jtframe writes DDR below 0x3800_0000
  after the download when only MR_DDRLOAD is set (loader is read-only,
  ddrmux grants it only while `ioctl_rom`). BUT the DDR line frame buffer
  writes at the same base: `ddram_addr = {4'd3, 0…, act_addr}` —
  jtframe_lfbuf_ddr_ctrl.v:68. A core using `JTFRAME_LF_BUFFER` (DDR
  variant) clobbers the staged image from the first frame. Retention
  strategy: rebase the lfbuf window to the top of the app region (e.g.
  {4'd3, 1'b1, …} = 0x3800_0000) via a parameter; ROM images are ≤64MB so
  0x3000_0000-0x33FF_FFFF is safe for the staged copy. This is a one-line,
  behavior-neutral lfbuf change that must land inside the PR.

## Architecture

One new module, `jtframe_ddr_rom` (MiSTer target):

- N client slots with the romrq contract (`cs/addr/ok/data`), so game code
  cannot tell DDR from SDRAM. Each slot has a direct-mapped cache
  (jtframe_romrq_lcache-style, size per bus from mem.yaml `cache_size`);
  fills are 64-bit-aligned bursts (1..128 beats, per-bus `blocks`-like
  knob), address = 0x3000_0000 + rom_offset(bus) + miss line.
- A third client on jtframe_mr_ddrmux: priority loader > ddr_rom > video
  (loader only runs during download; ddr_rom and lfbuf interleave by
  request, both burst-bounded). The mux grows from 2-way to 3-way; the
  existing "bad transfer while switching" caveat (jtframe_mr_ddrmux.v:68)
  must be fixed for the 3-way case by switching only between bursts.
- Clock: the ddr_rom runs on `clk_rom` like the loader (ddrmux already
  muxes `ddr_clk` per owner, jtframe_mr_ddrmux.v:67); slot outputs are
  therefore in the game clock domain — no new CDC on the client side.

### Latency and which buses qualify

DDR reads are fast in throughput but shared with Linux: latency is
100-300ns typical with occasional multi-microsecond spikes (to be measured
in phase 0 — the in-repo evidence of viability is the lfbuf, which streams
whole lines through the same port every scanline). Rules:

- CPU-class buses (main, wram, mcurom): never. A microsecond stall hangs
  the machine's timing assumptions.
- Streaming buses with FIFO slack (pcm): ideal. A C352 voice consumes
  bytes at ~24kHz per voice; a 512-byte FIFO rides out millisecond spikes.
- Line-buffered renderers (objrom when the core draws into a line/frame
  buffer ahead of the beam): good. Worst case a spike costs a cut line,
  never corruption.
- Beam-locked per-line fetchers (scr/roz-class): borderline; only behind a
  cache large enough that misses per line are few, and only after phase-0
  jitter numbers exist.

## mem.yaml design

New top-level `ddr:` section, buses identical to sdram buses plus a
mandatory fallback placement:

```yaml
ddr:
  - name: pcm
    addr_width: 22
    data_width: 8
    cache_size: 1kB
    rom_offset: PCM_START      # byte offset inside the .rom image
    sdram_fallback: { bank: 3 }  # used on targets without DDR
  - name: objrom
    addr_width: 23
    data_width: 32
    cache_size: 2kB
    rom_offset: JTFRAME_BA1_START
    sdram_fallback: { bank: 1 }
```

Semantics:
- On MiSTer (JTFRAME_MR_DDRLOAD present, `JTFRAME_NODDR` debug macro
  absent) the generator emits jtframe_ddr_rom wiring for these buses and
  omits them from the SDRAM banks.
- On every other target (and under JTFRAME_NODDR) each bus is appended to
  its `sdram_fallback` bank exactly as if written in the sdram section.
  One source of truth, both wirings generated from it; fits the existing
  per-target idiom (`when:`/`unless:` on buses, cf. rungun's POCKET ram
  bus, types.go:42-43).
- `rom_offset` is a byte offset into the .rom (download space), because
  the DDR image is the .rom itself; the existing `*_START` macros already
  name these offsets.

## Generator work

- types.go: `DDRBus` (reuse SDRAMBus fields + RomOffset, SdramFallback)
  with the standard strict-field validator; MemConfig gains `DDR []DDRBus`.
- mem.go/template: a `{{if .DDR}}` block in game_sdram.v (or a sibling
  include) instantiating jtframe_ddr_rom and the per-bus ports; fallback
  path folds the buses into the bank lists before bank emission so slot
  math is untouched.
- game ports: mem_ports.inc grows the same `name_cs/addr/ok/data` ports —
  identical either way, which is the point.
- MRA/downloads unchanged: bytes stay in the .rom in the same places; only
  the serving location differs. Optional follow-up: teach the loader to
  skip prog-writing regions that are DDR-served (faster load), gated
  behind its own switch since sdram_fallback targets still need them.

## Simulation strategy

Verilator has no DDR. The sim wrapper serves ddr buses from a behavioral
model reading `rom.bin` directly (it IS the DDR image), with a
configurable latency: fixed 150ns by default and a `+DDR_JITTER` plusarg
adding randomized multi-microsecond spikes so FIFO/cache sizing is
testable. Gates per phase in the house style: burst scene CRC unchanged,
scene sweeps pixel-compared, full-boot frames vs reference, boot pace and
coin canary.

## Phases

0. Measure: a probe counter on the DDR port (read latency histogram under
   OSD open/close, attract, gameplay) in a throwaway build. Numbers gate
   everything after.
1. pcm pilot: smallest risk, frees a bank-3 competitor; size the C352 FIFO
   from phase-0 worst case. Gates: CRC, sound-boot, long attract.
2. objrom: the prize (8MB bank freed, sprite bandwidth off SDRAM). Safety
   case: line-buffer-ahead rendering makes a spike = one cut line max.
   Gates: full sweeps + boot + bench soak.
3. Evaluate roz/scr against phase-0 jitter; only with per-line miss counts
   measured low.

## Risks

- Staged-image lifetime: any future DDR writer below 0x3800_0000 corrupts
  ROMs silently; the PR must document the DDR app-region map (staged ROM
  0x3000_0000+64MB, lfbuf rebased above it) and add a simulation assertion
  on write addresses.
- Linux-side traffic: worst-case stalls are unbounded in theory; that is
  why CPU buses are excluded by design and every served bus needs
  FIFO/line-buffer slack. Phase 0 turns this from folklore into numbers.
- Arbitration: a 3-way mux switching mid-burst corrupts transfers (existing
  2-way caveat, jtframe_mr_ddrmux.v:68); the redesign must grant per whole
  burst. Scaler pressure happens inside the HPS controller and shows up as
  added latency, not lost data.
- Portability surface: everything new is MiSTer-target files plus
  generator; other targets compile the fallback wiring and never reference
  DDR. Pocket/SiDi builds must be part of the PR's CI proof.
- LF_BUFFER coexistence: rebase + 3-way mux are mandatory before any core
  that uses the DDR lfbuf adopts ddr: buses (sysfl's C355 uses the BRAM
  lfbuf variant today, so the pilot core does not hit this, but the PR
  should solve it anyway).
