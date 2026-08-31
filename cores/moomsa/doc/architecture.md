# GX151 clean-room architecture contract

## Evidence boundary

This implementation uses the direct KiCad capture at
`D:\Arcade\AI\aCORES\Moo\docs\moomesa` as the primary authority for PCB
population, pin connectivity, buses and board-level nets. The checked parser
receipt is `doc/moomesa-kicad-audit.json`. SiliconRE evidence is supplemental
for custom-chip internals that the board schematic cannot expose; it cannot
override a direct KiCad connectivity fact. Text that explicitly derives a
behavior from MAME is quarantined and cannot define RTL. The currently
available AI-derived Moo Mesa core is excluded entirely.

## Current block map

```text
32 MHz oscillator
  ├─ MC68000 main bus ── program/work RAM, I/O, video registers
  ├─ K053990 bus ownership/protection (evidence blocked)
  ├─ K056832 behavioral tile owner ── 4bpp line renderer ── shared tile ROM (live)
  ├─ K054156 + K054157 physical boundary (pin/register continuity recorded; internal fetch blocked)
  ├─ K053246 + K053247 objects (partial live DMA/scan/draw transport; Moo sprite accuracy open)
  ├─ K053251 priority mixer ── K054338 color math ── 3× palette RAM ── RGB
  └─ K053252 programmable raster/interrupt shell ── renderer timing handoff (live, edge phase open)

18.432 MHz oscillator
  └─ Z80 ── YM2151 + 054986A/054321 ── K054539 PCM ── DAC/LA4705

JAMMA edge
  └─ four 005273 input arrays ── four 74LS257 muxes ── CPU input bus
```

The diagram is a worklist, not a claim that every named custom device is yet
implemented or that the K056832 raster scaffold is K053252-equivalent.

## Contracts still required

The live scaffold contracts are tracked in `doc/contracts.md`.

- complete boolean decode and physical address-pin/alias map;
- odd/even byte-lane and ROM interleave tests;
- oscillator/divider/CEN and reset-release phase measurements;
- coherent SDRAM request/acknowledge protocol for every ROM path;
- native sync, blanking, total, and refresh measurements;
- per-stage video valid/latency table;
- fixed-point audio width, gain, clipping, and latency table;
- 054539 contract is recorded in `doc/054539-contract.md`; sample/mixer paths
  remain blocked until physical evidence closes them;
- K054338 register/mix/shadow/brightness behavior is live in board mode through
  `hdl/jtmoomsa_054338.v`; the MCOL mux/latch network and three palette RAM
  lanes are collapsed into explicit behavioral FPGA boundaries. CRAM~CS,
  register/RAM phase, unnamed MIX1/BRI1 and analog transfer remain blocked;
- K053252 programmable raster/interrupt shell is live at the CPU/IRQ boundary
  in `hdl/jtmoomsa_053252.v`; the exact Moo startup vector is captured in
  `doc/k053252-moo-vector-20260825.txt`, and its sync/blanking/counter handoff
  is the sole live timing input to the Moo tile renderer. Board edge phase,
  reset release and final output alignment remain blocked;
- K056832 CPU windows, register state, byte-lane VRAM and tile-ROM arbitration
  are live in `hdl/jtmoomsa_k056832.v` and `hdl/jtmoomsa_k056832_romrd.v`; the
  Moo-local line renderer is in `hdl/jtmoomsa_k056832_renderer.v` and consumes
  the K053252 programmable timing handoff. Its 4bpp extraction and
  K054156/K054157 fetch semantics remain subject to native-frame comparison;
- the 005273/74LS257 input boundary is isolated in `hdl/jtmoomsa_inputs.v`;
  exact port decode, select polarity, and bit assignment remain blocked;
- K053990 arbitration and K054539 schedule assertions;
- K053990 pin-level bus boundary is recorded in `doc/053990-contract.md`; its
  DMA/protection behavior remains blocked;
- PAL20RS10 P6 equation or trace closure and all unverified decode paths.
