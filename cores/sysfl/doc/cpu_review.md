# jt960 / sysfl CPU engineering review

Deep review of the hand-written Intel i960-compatible CPU (`jt960`) embedded in
the Namco System FL core. Prioritized by ALM reduction and critical-path value.
The core is **ALM-bound** on the Cyclone V 5CSEBA6 (last fit: ALM 95%, M10K
93%, DSP 39% — logic is the binding constraint, DSP is abundant and underused).

Files reviewed: `hdl/i960/jt960.sv`, `jt960_dec.sv`, `jt960_alu.sv`,
`jt960_muldiv.sv`, `jt960_rcache.sv`, `jt960.vh`, `hdl/jtsysfl_main.v`,
`syn/timing.sdc`, `cfg/mem.yaml`, `cfg/macros.def`.

## Cycle-accuracy verdict

The arcade does **not** require i960 cycle accuracy: the core is already
non-cycle-accurate (fused 1-cen ops, 2-cen call/ret vs ~9 on silicon, 66-cen
div vs 37) and the game is frame-locked via the vblank/line IRQs and the C75
heartbeat. CPU speed only needs to stay **≥ current** so the main loop iterates
enough per frame. All fixes below are transparent at every `cpu_cen` edge.
**Do not trade away the fuse** for timing — it would halve IPC on cached code
and cost the 60 fps the cache size was chosen to hold.

---

## SAFETY FLAG — RESOLVED (d23424756 deleted the stanza): the committed read-return SDC exception (`e6584380b`) was unsafe

`timing.sdc` grants `md_r`/`f_hi`/`f_lo` → `cpu_regs` a **setup -end 2**
(2-clk) budget, but the real window is **one clk**: `md_r`/`mok_r` latch at
clk edge K, `cok` is the Q of `mok_r`, and the CPU can consume at a cen edge
at K+1. Unlike `icd_q` (stable for ≥2 launch edges before its consuming cen,
so its MC2 is safe by data stability), these registers change **one edge**
before the earliest legal capture. Under 95% ALM pressure the fitter is
explicitly told it may spend up to 41.7 ns on a 20.8 ns-real path — a latent
on-hardware corruption that **no simulation will show** (Verilator does not
model this). The same over-permissive pattern applies to `u_rcache|dout`
(1-clk real) and to the clk-rate sweep registers `swa`/`sweeping`/`icinv`
which fall inside the blanket `u_cpu|*` MC2. **This exception must be removed**
(by F1), not kept.

---

## F1 — DONE (d23424756) — remove the `din → decode → ALU → IP` cone in RTL, delete the SDC hack  (RANK #1)

**Hardware today.** `jt960.sv:142`: `dec_in = st==FETCH ? (ic_use ? icd_q :
din) : IR`. `din` (= `cdin` = `md_r`/`{f_hi,f_lo}`/`wram32_data`) fans into
`u_dec`, then via `dec_cls`/`IRe` selectors into `sx24`, the branch adders,
`u_alu`, and the `IP`/`r[]` writeback muxes — exactly the reported
`md_r → dec_in → u_dec → sx24 → Add0/Add1 → Selector → IP` path.

**It is a structural false path.** Enumerating every `din` consumer: outside
`dec_in`, `din` only loads registers directly (`IR`, `xdisp`, `tmp*`, `iac*`,
`mlo`, `icw_d`, `SAT/PRCB/IP` at reset) or goes through the short `rd64/rd64a`
byte-rotate + `mext` into `r[mreg]`. Decoder outputs are consumed by `do_exe`
only when `st==EXE` (then `dec_in==IR`) or `fuse` (then `dec_in==icd_q`, since
`fuse` requires `!bus_cs` and `ic_use` selects `icd_q`). On the FETCH bus-return
cycle the only decoder output used is `dec_ndisp` (word-length predecode). So
`din → dec → ALU → IP/r[]` is never sensitized in one cen.

**Patch** (`jt960.sv`):
```systemverilog
wire        ic_use = st==FETCH && !bus_cs && ic_hit;
wire [31:0] dec_in = ic_use ? icd_q : IR;
// displacement predecode for the bus-return word: din never enters u_dec.
// MEMB (op>=0x80, ir[12]=1) modes 5,c,d,e,f carry a 32-bit displacement
wire din_ndisp = din[31] && din[12] && (din[13] || din[13:10]==4'b0101);
```
and at line 519: `st <= din_ndisp ? XWORD : EXE;`
Then in `timing.sdc`: delete the `rdret_regs` stanza; add MC1 overrides for the
clk-rate sources `u_cpu|swa*`, `u_cpu|sweeping`, `u_cpu|icinv*`,
`u_cpu|u_rcache|dout*`, `u_cpu|u_rcache|fa_dout*` → `$cpu_regs`
(setup -end 1 / hold -end 0).

**Benefit:** removes the top reported timing path structurally, closes the
correctness hazard, and covers `wram32_data` which has **no** exception today
(the `latch:"1"` bcache output → `cdin` → same cone, 1-clk, uncovered — the
next failing path once `md_r` is quiet).
**Risk:** near zero — only *undecoded* opcodes whose bits look like a MEMB long
mode fetch one extra word before `HALT`. No implemented instruction changes.
Cycle-transparent. **Validate:** `ver/i960` tb + speed1_fast.cab boot.

## F2 — DONE (e9f46c2e1; +1.9% worst-case cen from the s1_ok branch wait; icd_q/ict_q/ic_ra now honest 1clk SDC sources) — real mid-cen pipeline register for decode + operand read  (RANK #2)

Even after F1 the fused hit path (`icd_q → u_dec → fuse → IRe mux → 4× 32:1
regfile mux → ea add / 64-bit funnel / branch adders → do_exe writeback → IP/
r[]`) is ≈42.4 ns — one monolithic cone; the **254+176 register duplicates**
are the fitter burning ALMs to fight it. `cpu_cen` has a guaranteed **minimum
2-clk spacing** and every sweep input is stable ≥1 full clk before the
consuming cen, so any pure function of them can be re-registered **every clk**
into a stage register whose value provably equals the combinational value at
the consuming cen edge — converting the SDC *promise* of 2 cycles into a *real*
register (two ≤20.8 ns halves).

Register at every posedge clk (no cen): `fuse_r`, `irq_take_r`, the decode
bundle (`cls_r,ndisp_r,msz_r,mcnt_r,msig_r,mreg_r,mdop_r,pair_r`), the selected
word/derived fields (`irx<=IRe; pipx<=PIPe; ipnx<=IPn`), and the regfile port
outputs (`a_r<=r[IRe[4:0]]; b_r<=r[IRe[18:14]]; c_r<=r[IRe[23:19]]`). Stage 2
(ALU, ea adders, tgt24/tgt13, do_exe muxes) consumes only `*_r`. Do **not**
route `din` through the stage. SDC: `s1_*` stage regs get MC1 both directions.

**Benefit:** each half well under 20.8 ns; duplicates melt as slack goes
positive → net **−200 to −400 ALMs** despite ~600 stage FFs (FFs pack into
existing ALMs; duplicates cost whole ALMs). Only credible route to a 60 MHz
clk (2-clk budget there = 33 ns < today's 42 ns sweep). Cycle-transparent by
the ≥2-clk spacing. 2–3 days; audit that no stage-2 net reads an unregistered
stage-1 net. **Validate:** i960 tb → boot → burst_07200 CRC.

## F3 — DONE (9cfcdd2d9; eng_rd = the four wdata states only — CALLS_EN needs live t1; md_s1 holds ediv src1) — merge the `wdata` regfile read port into port A  (~150 ALMs, RANK #3)

`r[0:31]` is flip-flops with four dynamic 32:1×32 read muxes (`t1`, `t2/c2`,
`t3/c1`, and `wdata=r[mreg]`). Each ≈170–180 ALMs. The `mreg` port is live only
in engine states (`MOVM`, `MWR1/2`, `MD_RDH`, spill/flush) — where `t1` is
dead.
```systemverilog
wire        eng_rd = st!=FETCH && st!=EXE;      // engine owns port A
wire [ 4:0] pa_a   = eng_rd ? mreg : IRe[4:0];
wire [31:0] pa_q   = r[pa_a];
wire [31:0] t1     = IRe[11] ? {27'd0, IRe[4:0]} : pa_q;
wire [31:0] wdata  = wsrc_rc ? rc_dout : pa_q;
```
Audited: no `wdata` consumer coexists with a live `t1`. Provably transparent.

## F4 — DONE (81162a09c) — ALU funnel shifter into DSP  (~150–200 ALMs → idle DSP, RANK #4)

`jt960_alu.sv:53-57`: a 64-bit left funnel shifted by 6 bits ≈ 6 levels of 64
2:1 muxes ≈ ~190 ALMs, plus a `32 - sh1` subtract in front. Shift-as-multiply,
right-shift complement via bit-reversed one-hot (the subtractor disappears):
```systemverilog
wire [32:0] oh_l = 33'd1 << sh1;
wire [32:0] oh_r;                               // one-hot of (32 - sh1), free
genvar gk; generate for(gk=0;gk<=32;gk=gk+1) assign oh_r[gk]=oh_l[32-gk]; endgenerate
wire [32:0] oh   = (f_sr||f_ext) ? oh_r : oh_l;
(* multstyle="dsp" *) wire [64:0] ph = fhi * oh;   // 32x33 unsigned
(* multstyle="dsp" *) wire [64:0] pl = flo * oh;
wire [63:0] fun  = { ph[31:0] | pl[63:32], pl[31:0] };  // == {fhi,flo} << famt
```
`fsh=fun[63:32]`, `fstk=|fun[31:0]`, `f_bit`, `extract` unchanged. ~4–6 DSP +
~35 ALUTs. Transparent; verify shift ops in the i960 tb.

## F5 — fold four 64-bit byte rotators into two  (~60–100 ALMs)

`wr64_d`, `wr64`, `rd64`, `rd64a` are state-disjoint:
```systemverilog
wire        disp_st = st==EXE || fuse;
wire [63:0] wr64s = {32'd0, disp_st ? t3 : wdata} << {(disp_st ? ea[1:0] : mad[1:0]), 3'd0};
wire [63:0] rd64s = (st==MRD2 ? {din, mlo} : {32'd0, din}) >> {mad[1:0], 3'd0};
```
Transparent.

## F6 — muldiv multiplier → DSP, keep the `done` cadence  (~100 ALMs)

Replace the radix-4 shift-add mul datapath with `(* multstyle="dsp" *) wire
[63:0] prod = s1l * s2l;` (latch `s2` at start, register `prod` once — 16 cens
of slack), keep `cntr==15 → fin → done` so mul still takes 18 cen (README
timing preserved bit-for-bit). Divider untouched. ~3 DSPs. Transparent.

## F7 — scanbit/spanbit as binary-search encoders

`jt960_alu.sv:160-172`: `for(i=0;i<32;i++) if(t1[i]) res=i;` synthesizes a
32-deep priority chain inside the ALU output cone. Replace with a 5-level
`msb32` binary-search encoder; `scanbit: res = |t1 ? msb32(t1) : -1`, `spanbit`
on `~t1`. Transparent (MAME semantics = highest set bit).

## F8 — one shared address adder for cold FSM states  (~100–150 ALMs)

`rd32/wr32` are called with ~12 distinct constant-offset addresses, each its
own 30-bit carry chain into a wide `addr` D-mux (≈250 ALMs). Restructure as
`addr <= abase + aofs` with one 32-bit adder + two ~10:1 muxes by state. Cold
states → zero timing relevance; medium typo risk — only with the i960 tb
passing before/after.

## F9 — register-file write-bus restructure → MLAB regfile  (strategic, not this week)

Writes to `r[]` come from ~10 sources at ~8 sites. Restructure into one
explicit write bus (`wr_idx`/`wr_en`/`wr_data`) + a per-local 2:1 vs `rc_q`
(RET_POP) + a small fixed-write set (r0/r1/r2/r31). The endgame is an MLAB
register file (3 replicated 32×32 banks ≈ 60 ALMs vs ~500–700 today) reading
via F2's registered addresses — but RET_POP parallel restore / rc_d parallel
spill pin r0–r15 to FFs unless call/ret are re-sequenced. Check the CI
entity-level ALM table before investing. F2+F3 keep this door open.

## F10 — board-side (`jtsysfl_main.v`)

- `wram32_data` SDC gap: fixed structurally by F1.
- `main_addr`/`main_cs`/`wram32_cs` are combinational from CPU regs into the
  SDRAM controller (1-clk cross-die, incl. a 19-bit adder + the 4-entry shadow
  CAM on live `a`). Latency-tolerant but a slow-`cs`/old-`addr` skew could let
  the controller latch wrong. **Contingency only** — if they show after F1/F2,
  register the request decode one clk (≤1 clk/request; most fetches hit L1).
- The `fun_regs` MC2 (CPU→CAPT capture) is genuinely safe (≥2-clk after launch).

## M10K sidebar (for the planned 16 kB icache restore)

`jt960_rcache.sv` forces 512-bit × 4 into M10K ≈ ~13 M10K for 2 kB (+1 for
`fa`) — worst bits/block ratio in the core. Repack as 256-bit × 8 (two beats
over the guaranteed 2 clks of CALL_RIP→CALL_FIN / RET_POP→RET_FIN) → ~7 M10K,
roughly paying for the icache's return to 16 kB (~+10 M10K). Flag for the same
pass as the icache restore.

## Minor / free

- `rpos` signed 16 → signed 8 (keeps depth-127 headroom; do not saturate).
- Drop the `for(j2) r[j2]<=0` reset (silicon/MAME leave regs undefined) — frees
  the LAB-wide sclr on 1024 FFs so `r` FFs pack with mux LUTs.
- `do_exe` inlined at two sites — folds into F2 (`if(cen && (st==EXE||fuse_r))
  do_exe;`).

## This week, in order

1. **F1** RTL + SDC cleanup (half a day; fixes the latent hazard + the wram32
   gap). i960 tb + speed1_fast boot.
2. **F3** + **F5** + **F7** (one day). i960 tb + boot.
3. **F4** + **F6** (one day). i960 tb (shift + mul/div) + boot + burst_07200 CRC.
4. **F2** mid-cen stage (2–3 days, incl. SDC + do_exe fold). Full validation.
5. CI fit after step 3 and after step 4 — the entity-level ALM table decides F9.

Expected: F1 alone should return worst slack to ~0 honestly (no unsafe
exceptions); F3–F7 recover ~450–600 ALMs; F2 recovers the ~430 duplicate
registers' ALMs and is the prerequisite for 60 MHz and the MLAB register file.
