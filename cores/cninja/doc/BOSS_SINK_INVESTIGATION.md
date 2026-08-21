# cninja stage-1 boss — sinking platform / girl bug (investigation)

Status: **SOLVED (Jun 2026).** The sink is pf1b COLSCROLL. **Root cause: the
deco16ic rowscroll/colscroll RAM in `jtcninja_video.v` was WRITE-ONLY** — the
CPU read port (`u_rs_*.q0`) was unconnected and `pf0/pf1_dout` returned tile
data for that address range. The boss-sink routine accumulates the colscroll IN
PLACE (`add.w (A4),D0` reads back 0x15c400, adds the delta, stores), so the
broken read-back made it compute `colscroll = delta` instead of `colscroll +=
delta` → it wobbled at 0 (fffc/0002, the shake) and never ramped → platform
shook but never sank. **Fix: connect each rowscroll RAM `q0` and mux it into
`pf0/pf1_dout` for the rowscroll address region** (using the existing per-game
`rs_*_we` decodes). General deco16ic correctness fix (also repairs rowscroll
read-back for darkseal/cbuster). VERIFIED in the full boss2 sim: colscroll now
ramps `fffc->ffee` and matches MAME frame-for-frame (both `ffee` at frame 2500).

## ★ BREAKTHROUGH (supersedes the X-vs-Y / 0x187802 theory below)

The earlier "sink = 0x187804 Y-damage accumulator" theory was WRONG. The actual
mechanism, traced end-to-end in MAME + isolated in the FPGA sim:

1. **The sinking ground/platform is the `pf1b` layer (tilegen1 pf1, VRAM
   0x154000), moved by per-column scroll (COLSCROLL).** Not sprites (the girl +
   player ARE sprites and render correctly; there is no platform sprite in
   OBJ-RAM). Not mg/bg (mg center is blank tile-0; mg/bg have no colscroll).
2. **pf1b colscroll is enabled**: tilegen1 control1 low byte = 0x20 (bit5 =
   colscroll). Colscroll RAM = `m_pf_rowscroll[2]` @ **0x15c000**, values in the
   `+0x200` word region (0x15c400).
3. **The sink ramps with boss HP** (MAME, boss2.inp): all 32 columns get the SAME
   value, ramping `0x0000 (HP13) -> 0xfffc -> ... -> 0xffce/0xffc0 (HP7)`, i.e.
   0 down to ~-64, clamped at -0x60. (Uniform across columns = effectively a
   whole-layer vertical scroll, done via the colscroll table.)
4. **Trigger = sink-state byte `0x18755c`.** HP=13: `0x00`. First boss hit
   (HP->10): flips to **`0xc0`** (bit7=active, bit6=init-done; bit5 later =
   sink-complete). Once 0xc0, the per-frame routine ramps the colscroll.
5. **Colscroll writer routine @ PC 0x25080** (disassembled, see below): gated on
   0x18755c bit7; steps an index `0x18755e` through a **delta table @0x2512e**
   (`fffc,0002,fffc,0002…` = -4,+2 → net sink + the earthquake wobble),
   accumulates, clamps to -0x60, writes all 32 colscroll columns
   (`move.w D0,(A4)+`). Two DECO104 checks (`cmpi.b #$57,$1bc7a4`,
   `cmpi.b #$8f,$1bc7a5`) — both CONSTANT (57/8f) and PASS on the FPGA, not the
   bug.

### FPGA render engine + write-path PROVEN CORRECT (injection test)
- `jtcninja_deco16` colscroll math matches MAME exactly
  (`mapy=(scrolly+screen_y+cs[src_x>>cs_sh])&hmask`, `cs_a=0x200+(src_x>>cs_sh)`).
- Captured MAME's pf1b colscroll RAM at frame 2700 (`/tmp/cnj_boss/rs_pf1b.bin`,
  cs=0xffce), injected it into `u_rs_pf1b` via a `SCENE_RS_PF1B` SIMFILE gate in
  `jtcninja_video.v`, re-rendered the `boss_sunk` scene → **the pf1b ground layer
  visibly SANK ~50px** (matches MAME). So the engine works.
- Write routing correct: main.v `pf1_cs = A[23:16]==0x15` → video.v
  `rs_pf1b_we = pf1_cs & A[15:13]==110` → `u_rs_pf1b`. 0x15c400 lands at RAM
  word 0x200, exactly where the engine reads it.

### Therefore the bug is CPU-side
The FPGA's 68000 must (a) set 0x18755c bit7 on first hit and (b) ramp the
colscroll @0x15c400. The platform-not-sinking symptom ⇒ one of those does not
happen on the FPGA. Confirming sim (snoops HP/0x18755c/0x15c400 in `_main.v`,
`FRAMES=2500 -inputs boss2_sim_inputs.txt`) running → if 0x18755c stays 0x00,
the divergence is the TRIGGER (find the setter, check its inputs); if 0x18755c
goes 0xc0 but 0x15c400 stays 0, the divergence is inside the @0x25080 routine.

### Trigger setter (MAME, boss2.inp)
- `0x18755c` byte goes `0x00 -> 0x80` (bit7) at **frame 2416 = first boss hit
  (HP 13->10)**, then `0xc0` (the @0x25080 routine adds bit6 init). Colscroll
  starts ramping frame 2420.
- bit7 is set by the BOSS AI at **PC 0x3D2F2** (and a sibling at 0x3D156):
  `move.b (A2,D7.w),D7` (HP-threshold from a ROM table indexed by boss field
  `(A0+0x68)`) → `cmp.w (A0+0x36),D7` (vs boss HP 0x18534c) → `bcs skip` →
  `bset #7,$18755c`. i.e. when boss HP crosses a per-stage threshold, sink fires.
- The two EARLIER setters (0x2592A gated on 0x18755a bit4, 0x25C82 on bit5) do
  NOT fire — confirmed: 0x18755a stays 0x40 (bit6 only) and the 0x18758c counter
  never increments. 0x184d82 = 0x03400000 (constant ROM config), 0x18755a = 0x40
  (constant ROM config) the whole fight. So the trigger has NO dynamic protection
  dependency — it's pure boss-HP + ROM-table, all of which the FPGA already runs
  (HP decrements, boss killable). ⇒ the FPGA SHOULD fire the trigger; the running
  sim decides whether it actually does.

Probe assets: `/tmp/cnj_boss/` — `rs_pf1b.bin` (MAME colscroll @f2700),
`sample_sink.lua` (HP/state/colscroll sampler), `cswriter.asm` (the @0x25080
disassembly), the per-layer FPGA renders (`fpga_{mg,bg,pf1b}_only.png`,
`fpga_colscroll_inject.png`).

---
## (older notes — partially superseded, kept for the CPU-trace addresses)

Status: **mechanism fully characterised in MAME; FPGA root-cause narrowed but not
yet fixed.** Reproduce everything from the committed input recording.

## Symptom (on MiSTer hardware)

During the stage-1 boss (the giant T-Rex head), the rocky **platform the player
stands on should sink into the ground as the boss loses life**, carrying the
captive **girl** down with it. On the FPGA the platform/girl **don't sink** — the
ground only *shakes* — and the girl then **snaps offscreen at the bottom** when
the player dies.

## Reproduction

`doc/boss1.inp` is a MAME input recording (MAME 0.276) that plays stage 1 to the
boss and dies on it. Replay deterministically and attach any probe:

```
/path/to/mame cninja -rompath ~/.mame/roms-local \
    -input_directory cores/cninja/doc -playback boss1.inp \
    -autoboot_script <probe>.lua -nothrottle -video none -seconds_to_run 66
```

Boss frame timeline (screen frame_number): boss visible ~2520, **HP=13 @2524**,
HP 12/11/8/5/2 at 2658/2708/2924/3298/3626, player dies ~3777 (mg tilemap clears).

## What we proved

1. **The sink is SPRITE-based, not tilemap.** The rocky platform + girl are
   sprites in OBJ-RAM (`0x1a4000`); their Y ramps down over the fight. The mg
   tilemap (tilegen0 pf2 = `0x146000`) only **toggles between two states
   (`6c3c16 ↔ 6a6c5d`)** — that's the *earthquake shake*, a VRAM rewrite — then
   clears at death. bg/tiles2 (`0x156000`) is static the whole fight.

2. **Boss HP is at work-RAM `0x18534c`** (mirrored at `0x187806`): spawns at 13,
   decrements per hit (13→12→11→8→5→2→0). **Platform/girl sprite Y = f(boss HP).**
   Verified visually: HP=13 → girl high on the rock platform; HP=2 → platform sunk
   away, girl at grass level.

3. **The two deco-55 (deco16ic) chips are NOT the cause.** Both chips' VRAM /
   control / rowscroll / read-back are wired symmetrically in `jtcninja_video.v`
   and match MAME's config (tilegen0 no bank-cb → FPGA `bank=0`; tilegen1
   `cninja_bank_callback` → FPGA `~|ctrl1[7][7:4]`). Both layers scroll correctly
   in normal play (confirmed on hardware).

4. **deco16ic scroll registers are NEVER written during cninja gameplay** — the
   control regs at `0x140000`/`0x150000` and the rowscroll RAMs stay static the
   whole recording. cninja does **not** scroll via the hardware scroll register;
   the camera/level is driven another way (object table at `0x184xxx`). So the
   sink is definitely not a scroll the FPGA is dropping.

5. **On hardware HP decrements fine and the boss is killable** → the hit/HP path
   (and the DECO104 protection that mediates it) is **working**. So the bug is
   **case (b): the routine that derives the platform/girl sprite-Y from boss HP**
   (or the FPGA's sprite-Y rendering of that value), NOT a missing decrement.

## CPU trace of the sink logic (MAME, boss object at A0=0x185316)

- Boss HP = `(A0+0x36)` = `0x18534c`. Decremented at PC **0x12056** (`sub.w D6,(A0+0x36)`).
- HP **bar** (red segments) is drawn into the FG tilemap at `0x144000`+ by the loop
  at PC **0x1c0a0** (reads HP, writes tile 0x2000 ×HP). Not the sink.
- **Damage accumulator** at PC **0x430b0**: each frame computes the per-frame
  damage and accumulates it into **`0x187802` (X)** or **`0x187804` (Y)**.
- The X-vs-Y routing comes from the helper at PC **0x43254**: it reads the boss
  **hit-direction byte `(A0+0x24)`** (quadrant compares vs 0x80/0x90/0xa0) plus
  work-RAM `0x184ddc`/`0x184d9c`, and sets `D0` bit 8. The accumulator then does
  `btst #8,D0` → Y (`0x187804`, **the SINK**) vs X (`0x187802`, horizontal shake).
- **The platform/girl sink ∝ `0x187804`** (accumulated Y-damage). If the FPGA
  routes damage to X instead of Y, the platform shakes but never sinks — matches
  the symptom exactly.
- **Every input to this is work RAM / object fields. No DECO104 protection read,
  no deco16ic.** (The earlier `cmpi.b #X,$1bcXXX` "protection gates" were
  disassembler misalignment — those addresses are never read during the boss.)

So the CPU *code* is identical between MAME and FPGA; the divergence is an
earlier game-state or timing difference that makes the FPGA route damage to X
(or never accumulate Y). Static MAME analysis cannot localize it further — it
needs the FPGA's own CPU state at the boss.

## Next step (open)

**Only reliable path: get the FPGA CPU to the boss and diff its work RAM vs MAME.**
Convert `boss1.inp` to a jtframe `.cab` input script, run the full Verilator sim
~2500 frames (~45 min) feeding those inputs, and compare `0x187802/0x187804` +
`(A0+0x24)` against MAME frame-by-frame. The first frame they diverge is the bug.
(Alternative: temporary FPGA debug build that surfaces `0x187804` on hardware.)

Earlier open phrasing below is superseded by the trace above.

## Input-replay sim setup (ready to execute)

To drive the FPGA Verilator sim to the boss with the same inputs:

1. **Per-frame inputs** dumped from the MAME replay (Lua: read `:INPUTS` /
   `:SYSTEM` ioports each frame). Only the low byte of `:INPUTS` (P1) and
   `:SYSTEM` bit0 (coin) matter; ~233 changes over the run.
2. **sim_inputs.hex** = one hex value per FRAME (test.cpp reads one line/frame,
   then `v=~v`). Bit layout (active-HIGH in the file): `coin=0x1 service=0x2
   1p=0x4 2p=0x8 right=0x10 left=0x20 down=0x40 up=0x80 b1=0x100 b2=0x200
   b3=0x400 test=0x800 reset=0x1000`. cninja is `JTFRAME_JOY_RLDU`, so
   apply_joystick lands joy[3:0]={R,L,D,U}, joy[6:4]={b1,b2,b3}; the deco104
   reads joystick1 as the INPUTS port. So map each MAME INPUTS/SYSTEM frame to
   the cab bit value and emit one line/frame for ~4003 frames.
3. Rebuild cninja sdram banks, run the sim to ~frame 2520+ (~45 min, the SPI
   download eats ~107 frames, then ~2400 game frames), dumping
   `0x187802/0x187804/(A0+0x24)` via `JTFRAME_IOCTL_RD` or a `$display`.
4. **Diff against MAME** frame-by-frame; first divergence = the bug.

CAUTION: validate the bit mapping on a SHORT run first (≈300 frames, confirm the
player walks/attacks like MAME) before committing to the 45-min run — a single
bit-order error makes the whole replay diverge from frame 1.

## Ready-to-run assets (boss2, the shorter capture)

- `doc/boss2.inp` — shorter MAME recording: reaches the boss at **frame 2144**,
  first damage @2416, HP driven 13→4 before death. Sim only needs to run to
  ~frame **2700** to expose the X-vs-Y damage-routing divergence.
- `ver/cninja/boss2_sim_inputs.hex` — pre-generated `sim_inputs.hex` (2801
  frames, cab format, one line/frame), from boss2.
- Regenerate: replay boss2 with `mame_scripts/dump_perframe_inputs.lua`
  (writes `frame INPUTS SYSTEM` per line), then
  `mame_scripts/inp2siminputs.py perframe.txt > sim_inputs.hex`.

**Run-time caveat (still to validate):** the Verilator sim spends ~107 frames on
the SPI ROM download before the CPU starts, so the MAME game-frame N ≠ sim-frame
N. When running, either pad `sim_inputs.hex` with ~107 leading idle (`0`) lines,
or confirm test.cpp only consumes inputs once the CPU is out of reset. Validate
the player reaches the boss in sim at ~the same relative point as MAME before
trusting the diff. The bit mapping itself (cninja `DATAEAST_2BUTTON`: P1 lo byte
bit0=U bit1=D bit2=L bit3=R bit4=B1 bit5=B2 bit7=START; SYSTEM bit0=COIN) is in
`inp2siminputs.py`.

Trace the MAME code that writes the platform/girl sprite Y during the sink (e.g.
a watchpoint on the work-RAM that feeds it, or on the OBJ-RAM Y of the sinking
slots), and identify every input it reads besides `0x18534c`. Whatever extra
input it uses that differs on the FPGA is the divergence. Then verify the FPGA
provides that value, or that its sprite engine renders the computed Y correctly
(the "snaps offscreen" hints at a Y-value/wrap mismatch).

Probe scripts used live under `/tmp/cnj_boss/` during the session (transient);
the reusable artifact is `boss1.inp`.
