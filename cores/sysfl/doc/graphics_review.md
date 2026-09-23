# sysfl graphics subsystem review

Deep review of the graphics engines (C355 sprites, C169 ROZ/affine, C123
tilemap, C116 mixer). Prioritized by ALM reduction and critical-path value.
The core is **ALM-bound** on the Cyclone V 5CSEBA6 (last fit: ALM 95%, M10K
93%, block-mem bits 69%, DSP 39% — logic is the binding constraint; DSP is
abundant and underused; moving arithmetic into DSP is high value).

Files reviewed: `hdl/c355/jtc355.sv`, `c355/jtc355_scan.sv`, `c169/jtc169.sv`,
`c123/jtc123.sv`, `c116/jtc116.sv`, `hdl/jtsysfl_video.v`, `cfg/mem.yaml`,
`cfg/macros.def`, `jtframe_obj_buffer.v`, `jtframe_linebuf.v`.

All findings are bit-exact and name their proof-sim (burst_07200 CRC
`7f74b8fd/e0e89c81`, `SYSFL_LNDUMP` stream diff, or the speed1_fast.cab boot).

## Pixel-critical path

Three true 48 MHz single-cycle loops are the Fmax risks:
1. C355 drawer pixel write — `rowb` MLAB read → pen mux → `pen!=ff`/`xok`
   compares → **512:1 `wmask[wa]` mux** → `ln_we`/`wmask`/`gfull` update.
2. C169 back-end `popst/pophit` cone — `fifo[f_rd]` MLAB async read → three
   19-bit equality compares + opq compare → pop → address-register enables.
3. C355 drawer `pop` cone — `fifo_rd` MLAB read → 4×13-bit signed clamp/adds →
   two 64-bit shift/subtract → 64-bit AND-reduce (`q_cov`) → `frp`/fetch.

Already per-line/per-sprite (not re-proposed): zoom reciprocal mults, ROZ DDA,
viscache/span/dyq caches, opq skip table, DMA snapshot, coverage skip.

## F1 — DONE (0f3c43da1) — C355 `wmask`: 512-bit flat register with per-pixel dynamic index  (biggest ALM)

`jtc355.sv:121,250-256`. 512 FFs each with an individual load-enable, a
**512:1 read mux**, an 8-bit dynamic part-select (8× 64:1 muxes), and a 576-FF
sync clear on `ln_hs`. Hundreds of ALMs + heavy routing, inside the single-cycle
pixel-write loop (also a top Fmax suspect). **Per pixel.**
Keep `gfull` (64 FFs — needed combinationally by q_cov/sc_cov/line_full); move
the fine mask to `(* ramstyle="MLAB, no_rw_check" *) reg [7:0] wmaskg[0:63]`
with **async read + same-cycle RMW**: read word `wmaskg[wa[8:3]]`, test bit
`wa[2:0]`, write the word back with the bit set on every accepted write;
`gfull[grp] <= &word_after_write`. Clear = 64-cycle sweep at `ln_hs` (gate `pro`
on `clr_bsy`; first descriptor needs ~20 cycles anyway; 3053 clk/line budget —
watch OBJDBG `maxl`). MLAB async read keeps the RMW single-cycle.
**Benefit:** largest single ALM item, routing, Fmax. Cost ~2–3 MLABs.
**Proof:** LNDUMP byte-diff → burst_07200 CRC; OBJDBG maxl/cut for sweep cost.

## F4 — DONE (9106ce553) — C355 drawer `q_cov` cone duplicates scan math; put gl/gh in the descriptor

`jtc355.sv:163-175` + `jtc355_scan.sv:163-171`. The drawer recomputes
clip/clamp/flip/group-span from raw FIFO bits (~6×13-bit signed add/compare +
flip muxes) then `(64'h2<<q_gh)-(64'h1<<q_gl)` (two 6→64 decoders + 64-bit
subtractor); the scan has an identical copy. The drawer copy is on the
MLAB-read→`pop` critical cone. **Per column descriptor.**
(1) The scan already computes `sc_gl/sc_gh` before pushing — **put gl/gh (12
bits) in the descriptor** (93→105 bits, MLAB doesn't care) and delete the
drawer's whole clamp cone; the drawer only re-applies the *current* `gfull` at
pop. (2) Replace `(2<<gh)-(1<<gl)` in both with per-bit window compares
`rng[i]=(i>=gl)&&(i<=gh)` (~1 ALM/bit, kills the 64-bit subtractor). (3)
Optionally register the pop decision one stage (FIFO has slack).
**Benefit:** Fmax (shortens the pop cone), ALM. **Risk:** none — gl/gh frozen
at push, only gfull evolves and is still sampled at pop. **Proof:** LNDUMP
diff → CRC. **Do F1+F4 together.**

## F2 — DONE (2800bc3ef) — C355 scan: three 256-deep MLAB arrays → one M10K

`jtc355_scan.sv:78-84`. `span0`/`span1` (256×13), `dyq_c` (256×12), `viscache`
(256×1) as MLABs need 8-bank depth stitching + output muxes ≈ 20–30 LABs
(200–300 ALM-equiv), with 41 M10K free. **Per sprite entry per line.**
Pack into one M10K 256×39 ({vis,span0,span1,dyq}). M10K read is synchronous;
`online`/`sp0`/`sp1` are consumed combinationally in `LIST t==0` for the 1-cycle
skip — fix by issuing the read for `entry±1` speculatively in `ENXT`/skip
(address reg loaded when `entry` updates); worst case skip loop 2 cyc/entry
(+256 clk, well inside 3053). **Benefit:** ALM (second-biggest), +1 M10K.
**Proof:** CRC; SOBJ scan-time; boot.

## F5 — DONE (6a6cc6d35, tags only; DSPs abundant so no operand-mux sharing) — DSP migration (DSP 39% used)

Each a free-running combinational multiply (verify per-entity in the CI fit
DSP section):
- `jtc355_scan.sv:129/135/157`: `shr*recip(rleft)`, `colq0m`, `colqm` (10×19),
  **mutually exclusive by FSM state** — share **one** multiplier behind a 3:1
  operand mux, `(* multstyle="dsp" *)`.
- `jtc355_scan.sv:264/324/369`: `dyf[7:0]*vsize`, `dxf[7:0]*hsize` (8×10) —
  also state-exclusive; fold into the same DSP or tag.
- `jtc169.sv:337-338`: `p_incyx*lline`, `p_incyy*lline` (24×9, per line) — tag
  dsp.
- `jtc169.sv:335-336`: `p_ax/p_ay` 4-term shift-add chains → `36*p_incxx +
  3*p_incyx` on a DSP (frees ~6 wide adders).
**Benefit:** ALM (the 8×10s likely in logic today), Fmax on the ROWC loop.
**Proof:** CI fit DSP count per entity; CRC.

## F3 — DONE (dbdff7feb; registered 12-CE sort of unique {prio,idx} keys + flat encoder, diffs exact) — C123 per-pixel 6-deep serial priority chain

`jtc123.sv:220-227`. The `for(j=5..0)` loop is a *sequential* dependency
(`cprio` from j+1 feeds the compare at j): 6-stage compare+7-bit-mux cascade
per `alt_cen`, feeding `{attr,scr_addr}` (→ SDRAM). **Per pixel.**
Winner = opaque layer with max `cfg_prio`, ties to higher index; none opaque →
win=0. Precompute per line (hs, tiny FSM ≤36 clk) a priority-sorted order
`ord[0..5]`; per pixel reorder the 6 opacity bits through `ord` → flat priority
encoder → `win=ord[enc]`, `cprio=cfg_prio[win]`. Depth ~6 stages → ~2–3 LUT
levels. (Alt: a 64×7 LUT indexed by the opacity vector, rebuilt per line.) Keep
none-opaque→win=0 so the fetch pattern is unchanged.
**Benefit:** Fmax, some ALM. **Proof:** CRC; boot (attract mixes all 6+ROZ).

## F6 — DONE (8376ddb55; skid + empty-queue push bypass, cycle-exact; naive skid without the bypass doubled road-scene ROZ cuts) — C169 FIFO no ramstyle; back-end cone unregistered

`jtc169.sv:109-141`. `reg [48:0] fifo[0:3]` sync-write/async-read with **no
attribute** → often 196 FFs + 49×4:1 mux instead of MLAB; then `h_msk/h_til/
h_code` feed three 19-bit + one 14-bit comparators combinationally into
`pophit/popst` (longest cone in the module). **Per pixel.**
Add `(* ramstyle="MLAB, no_rw_check" *)`; register the FIFO head into a 49-bit
skid reg (reloaded on pop) so comparators work on FFs. Folds with the existing
`opq_cl` one-cycle-delayed compare. **Benefit:** ALM, Fmax (needed for 60 MHz).
**Proof:** CRC + ROZDBG `cut=` must not increase on road scenes.

## F8 — DONE (b56032972; rgb_addr/opq/h-v windows registered, diffs exact) — C116 mixer: not a giant priority mux, but unpipelined across 3 BRAMs

`jtc116.sv:99-125`. The mixer is small (two 4-bit compares + a 13-bit 3:1 mux)
— no giant mux. But line-buffer-dout → mixer → palette-BRAM address in **one
48 MHz cycle** across three modules, plus `vwin/hwin` (4×9-bit compares +
adders) per pixel. With 8 clk/pixel this is unused slack.
Insert one register on `rgb_addr`/`lyr_obj`/`bg_opq` (align `blank`); compute
`vwin` once per line, register `hwin`. **Benefit:** Fmax/routing headroom (the
60 MHz enabler more than an ALM saver). **Proof:** CRC (any misalignment shifts
the whole image).

## F7 — C169 per-pixel Y-wrap recomputes from scratch

`jtc169.sv:169-172`. `cyfw = cy - p_ay` is a free-running 24-bit subtractor per
pixel, then a 12-bit mod-0xc00 fold — a "start+offset" recomputation where an
accumulator exists two lines up (`cy += p_incxy`). **Per pixel.**
Maintain `cyf` (= cy − p_ay) as its own accumulator (init in CALCC = `sy24 +
lyt`, step `cyf += p_incxy`); the 24-bit subtractor disappears; keep the
mod-0xc00 fold. **Benefit:** ALM, Fmax on the map-address cone. **Risk:** the
3072-px Y-ring wrap (Speed Racer road) — exactly what burst_07200 exercises.

## F9 — width diet

- `wx0/wx1` pushed post-clamp to [0,287] but carried 2×13-bit signed and
  compared 13-bit per pixel — carry 9-bit unsigned; `xdr/xcur` fit 11-bit
  signed. Saves FIFO bits + narrows two per-pixel comparators.
- `jtc123.sv:85,204-217`: `hoff/hpos/vpos` 16-bit with 16-bit adder trees for
  10-bit-significant results; narrow to 10–11 bits.
**Benefit:** ALM/reg (small, several sites). **Proof:** CRC + boot.

## F10 — bandwidth map (state; no mass replication proposed)

C123: 1 tile-ROM byte/pixel (winning layer only), 1 mask + 1 BRAM word/tile/
layer; per-pixel SDRAM hidden by `alt_cen` (2 clk/px) + 1 kB cache; scales to
60 MHz. C355: 4×32-bit/16-px column, 64-bit bursts, fetch overlaps draw,
coverage-skip removes hidden columns — balanced. C169: residual texel
serialization on bank 0 is the known bound (bank duplication = known unbuilt
lever). **New observation:** `rmask` lives on bank 3 with `wram32` (i960 code
fetches, "one burst per word") and C352 PCM streaming — the busiest CPU bank.
**Before building texel bank duplication, try moving `RMASK_OFFSET` to bank 2**
(scr/smask/mcurom — no continuous streamer) and re-measure `ROZA cut=` on road
scenes; the opq table killed most mask fetches, but the remaining misses queue
behind CPU bursts. **Proof:** ROZDBG cut/wait on the road stretch, then CRC.

## Suggested week plan

1. F1 (wmask→MLAB RMW) + F4 (gl/gh in descriptor) together — biggest ALM cut,
   both drawer critical cones fixed. LNDUMP byte-diff → CRC.
2. F2 (scan caches → one M10K) — mechanical, second-biggest ALM.
3. F5 (DSP tags/sharing) — check CI fit log first.
4. F3 (c123 priority) + F6 (c169 skid) — the two per-pixel chains; F8 for 60 MHz.
F7/F9/F10 as fillers.

**Not worth touching:** c123's shared 6-layer prefetch pipe; the C355 DMA
(fits vblank with 3.5× margin); the line buffers (correctly sized M10Ks, no
oversized framebuffers). No DONE item needs reverting.
