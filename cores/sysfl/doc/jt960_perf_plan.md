# jt960 throughput plan: run the i960 at its real 20 MHz

## Goal

`cpu_cen` in `cores/sysfl/cfg/mem.yaml` is 46 MHz today (2.3x the real i80960KA-20)
because jt960 is slow per instruction. Make jt960 fast enough that the game runs
with `cpu_cen` = **20 MHz**, with the same amount of free time per frame as MAME
at 20 MHz. Only then is the core clocked like the PCB.

Success = with `cpu_cen` at 20 MHz:
1. per-frame main-loop idle time in the RTL is >= MAME's (measured, not guessed),
2. `ver/i960/go.sh` passes,
3. the full sim `speed1_fast.cab` still boots, takes 3 coins, starts and races
   (same checkpoints as today, see Verification),
4. `SYSFL_VSTAT` shows no new C123/ROZ line misses.

## Context you need

- Core: `cores/sysfl` (Namco System FL, Speed Racer `speedrcr`). MAME reference
  driver: `~/develop/mame/src/mame/namco/namcofl.cpp`; CPU reference:
  `~/develop/mame/src/devices/cpu/i960/i960.cpp`. MAME binary for this game is
  **`~/develop/mame/sysfl`** (never `./mame`), ROMs in `~/develop/mame/roms`,
  run from `~/develop/mame` with `-rompath roms`. MAME writes NVRAM on exit: use a
  scratch copy of `~/develop/mame/nvram/speedrcr` via `-nvram_directory`.
- CPU files: `cores/sysfl/hdl/i960/` (`jt960.sv` sequencer, `_dec`, `_alu`,
  `_muldiv`, `_rcache`, `jt960.vh`, `README.md`). Keep everything inside this folder
  (approximate chips stay in the core).
- System glue: `cores/sysfl/hdl/jtsysfl_main.v` (address decode + 32->16 bus
  funnel), `cores/sysfl/cfg/mem.yaml` (SDRAM buses, clocks).
- Sims run in the local docker image `jotego/simulator:arm64` (no verilator on
  the Mac, never suggest brew). Full sim, from `cores/sysfl/ver/speedrcr`:

      docker run --rm -v "$HOME/develop/jtpublicfork":/jtcores -v "$HOME/develop/jotego-support":/jotego \
        -e JOTEGO=/jotego -w /jtcores/cores/sysfl/ver/speedrcr --entrypoint bash jotego/simulator:arm64 \
        -c "source /jtcores/setprj.sh >/dev/null 2>&1; jtsim -video 2700 -d SYSFL_VSTAT speed1_fast.cab"

  `make_sdram.py --fastboot` must have been run once (patches POST delay loops,
  SIM ONLY). 2700 frames take ~18 min; 400 frames ~3 min. The `.cab` is a
  positional argument (no `-inputs`). Coins land at frames 260/282/310, start
  ~343, race from ~850.
- CPU unit test: `cores/sysfl/ver/i960/go.sh` (iverilog smoke TB, must print PASS).
- Do not read frame PNGs to judge results; use text counters. Do not edit
  `modules/jtframe` (upstream). Commits: no Claude attribution/co-author lines.
  Comments: one terse line max, match the existing style.

## Current design (what makes it slow)

Numbers are per the code today; confirm them with the instrumentation below.

1. **Fetch/execute are serial.** `FETCH` (jt960.sv ~L349) either hits the icache
   (1 cen) or issues `rd32(IP)` and waits for `bus_ok`; then `XWORD` for a
   32-bit displacement, then `EXE` (1 cen, L387) -> back to `FETCH`. So even a
   cache hit costs 2 cen per simple instruction; nothing overlaps.
2. **Icache latency.** Now 1 kB (`ICACHE_BLK`), but a hit still waits one clk
   for the registered RAM read and a miss fetches a single word.
3. **Bus latency.** Program/data ROM goes straight to SDRAM bank 0 (`main` bus,
   32-bit, now behind a 1 kB `cache_size` in mem.yaml). Everything else goes
   through the funnel in `jtsysfl_main.v`: IDLE -> SETUP -> WAIT -> NEXT per
   16-bit half, BRAM targets wait until `cnt==2`, work RAM (`wram`, SDRAM bank 1,
   16-bit rw) needs two SDRAM accesses per 32-bit word. Loads/stores and every
   frame spill/fill pay this.
4. **Frame cache copies 1 word/cycle** (16 cycles per call/ret, silicon ~9) and
   spills to memory beyond 4 frames.
5. MAME charges fixed cycles per instruction and treats memory as free (most
   ops `m_icount -= 2..4`, mul 37, div ~30-37). So MAME at 20 MHz is the
   throughput to match, not a bus-accurate model.

## Phase 0 results (19-9-2026) - READ FIRST

Measured with `-d SYSFL_VSTAT` (prints `CPUSTAT` per frame from
`jtsysfl_game.v`; the same block has an optional `PCS` PC sampler) and MAME
`./sysfl` traces. Note `speed1_fast.cab` drops 678 frames: RTL frame N ~ MAME
frame N+678.
- **The game logic runs at 30 Hz in the RTL.** The race frame counter at
  0x100ff050 (+1 per frame in MAME) is written only every other frame
  (`fcnt_wr` alternates 10/0).
- **`cpu_cen` is really 24 MHz**, not 46: a jtframe cen cannot exceed clk/2
  (405,504 cen per 811,007-clk frame). 20 MHz real = 335k cen/frame.
- MAME race frame 1780: 118.8k instructions, **42.7k non-idle** (idle loop
  0x100004E0-F4), IRQ 0/1/2 once each. RTL IRQs match. The RTL runs the same
  code (same hot PCs), it is just too slow: ~11 cen per busy instruction, so one
  update takes ~1.2 frames.
- RTL cen by state in the race: MRD1 35% (loads), FETCH 29%, MWR1 16% (stores),
  MDWAIT 8% (muldiv), XWORD/EXE/other 12%. **The data side is the bottleneck.**
- Targets: busy CPI <= ~6-7 for 60 Hz at 24 MHz cen; <= ~5-6 for real 20 MHz.
- C75 is fine (RTL 91% idle vs MAME 88%); leave it alone.
- Already done: parametric 1 kB icache (`ICACHE_BLK`), sequential read-ahead,
  single-word instructions fused into the FETCH cycle on a hit, `main` and other
  ROM buses behind 1 kB mem.yaml caches.

## Phase 1-3 results (19-9-2026)

Measured with the `CPUDET` line (per-access cen by target, see `SYSFL_VSTAT`
in `jtsysfl_game.v`), race frames 1100-1140 of `speed1_fast.cab`, 1500-frame
runs. MAME frame 1780 (= RTL ~1102) executes 42.7k non-idle instructions over
only **2,831 unique PCs (~11-12 kB of code)**, all in work RAM.

What Phase 0 had missed: **the whole game runs from WRAM** (PCs 0x100xxxxx),
so every icache miss and 32-bit displacement went through the 16-bit funnel
at ~13 cen/word; with a 1 kB icache and word fills that was 134k cen per
busy frame (33%), more than loads (84k) or stores (36k).

| item (busy race frame, 24 MHz cen)  | before      | after       |
|-------------------------------------|-------------|-------------|
| game update length                  | ~470k cen (1.2 frames) | ~241k cen |
| `fcnt_wr` per frame                 | 10 / 0 alternating (30 Hz) | 8-10 every frame (60 Hz) |
| idle cen per frame                  | 52 / 340k alternating | ~164k every frame (40%) |
| ld WRAM cen/access                  | 13.6        | 11.5        |
| st WRAM cen/access (CPU side)       | 12.9        | 6.3 (posted)|
| st BRAM cen/access                  | 6.1         | 1.2 (posted)|
| fetch-miss cen/frame                | 134k        | 19.5k       |
| mul/div cen (count)                 | 66k (1769, 37/op) | 39k (1703, 23/op) |
| call/ret cen (count)                | 6.3k (188)  | 0.8k (186)  |
| frame spill/fill cen/word           | 12.2        | 9.8         |
| coins / milestones / c123 misses    | 269,291,320 / 13 / 0 | same |

Changes:
1. `jtsysfl_main.v` funnel: request latched at accept (registered address to
   the BRAMs), writes posted except sysreg (the CPU gets `bus_ok` on accept,
   the next data access waits for the engine), no SETUP/NEXT/DONE states:
   WRAM halves are separated by one clock with `wram_cs` low (the rw slot
   needs a cs edge), BRAM halves take 2 clocks, `fok` returns straight from
   the last half.
2. `wram32` bus (mem.yaml, bank 1, 32-bit read-only over the WRAM region):
   instruction and displacement fetches from WRAM (`jt960.fetch`) use it, one
   SDRAM burst per word instead of two 16-bit funnel passes. No `cache_size`:
   the plain ROM slot keeps only the last two words, so self-modifying code
   is only exposed for two fetches. Data reads stay on the funnel because a
   load right after a store to one of those two words would read stale data.
3. `jt960`: 16 kB icache default (`ICACHE_BLK=64`, 16 M10K), loads/stores
   issue their first bus beat in the dispatch cycle, `mov/movl/movt/movq` in
   one cycle, whole-frame register cache copy (call 2 cen, ret 2 cen),
   radix-4 multiplier (18 cen like MAME).

At 20 MHz cen (337,920 cen/frame) the game still runs at 60 Hz: idle 121k
cen every frame (36%), busy 217k. Side effect: the denser CPU request stream
on SDRAM bank 1 (round-robin bank arbitration) costs the video a few pixels:
c123_miss 29 (53 px) and roz_miss 215 over frames 1000-1149 vs 0 / 123 in
the baseline. Most of the traffic is the idle loop (`ld 0x100f5d2c` poll,
~10k per frame, two 16-bit SDRAM reads each).

4. Data loads from WRAM also go through `wram32` (one burst, and repeated
   polls of one word are served by the slot's 2-word buffer with no SDRAM
   traffic). Coherence: `jtsysfl_main` shadows the slot's last SHW=4 missed
   words; a WRAM write flags matching entries dirty and a load hitting a
   dirty word, or issued while a write is still posted, takes the 16-bit
   path. SHW only needs to be >= the slot's buffer depth (2). DECISION
   POINT: this mirrors `jtframe_romrq_bcache` behaviour; the alternative is a
   write-through data cache inside jt960 with a `cacheable` input.

Result at 20 MHz with 4 (race frames 1100-1140, `speed1_fast.cab`):

| item                         | 24 MHz, funnel loads | 20 MHz, wram32 loads |
|------------------------------|----------------------|----------------------|
| cen/frame                    | 405,504              | 337,920              |
| idle cen/frame               | ~164k (40%)          | ~169k (50%)          |
| busy cen/frame               | ~241k                | ~169k                |
| `fcnt_wr`                    | 8-10 every frame     | 8 every frame        |
| ld WRAM cen/access           | 11.5                 | 4.4 (polls 1.3)      |
| st WRAM / BRAM cen/access    | 6.3 / 1.2            | 5.1 / 1.1            |
| fetch-miss cen/frame         | 19.5k                | 17.0k                |
| mul/div cen/frame            | 39k                  | 41k                  |
| c123_miss, frames 1000-1499  | 69 (baseline 0)      | 0                    |
| roz_miss, frames 1000-1499   | 854 (baseline 496)   | 486                  |
| roz_lost_px, frames 1000-1499| 5334 (baseline 2363) | 3106                 |
| coins / milestones           | 269,291,320 / 13     | same                 |

Video is back at the baseline numbers once the polls stop hitting the SDRAM
(the CPU now issues ~18k SDRAM accesses per frame vs ~36k before). ROZ lost
pixels are still ~30% above baseline (about 6 px/frame, same miss count):
the ROZ engine was already at its margin; a larger `roz` cache_size in
mem.yaml is the video-side knob if it shows.

Knobs not explored: `ICACHE_BLK=32` (8 kB, half the M10Ks; fetch misses
will grow from ~4k/frame), divider at 2 bits/cycle (MDWAIT is 12% of the
busy frame, mostly the 18-cen muls).

## Phase 0 - measure (do this first, report numbers before changing RTL)

A. RTL counters, behind a new macro `JT960_STAT` (SIMULATION only), printed once
   per frame on the rising edge of vblank (see the `SYSFL_VSTAT` block at the end
   of `jtsysfl_game.v` for the pattern; `u_main.u_cpu` or the actual instance
   path):
   - `cen` cycles, instructions retired (count `EXE` entries),
   - cycles by state class: fetch-wait (FETCH/XWORD with bus_cs), exec,
     data read wait, data write wait, call/ret/frame copy, interrupt entry,
   - icache hits/misses,
   - **idle cycles**: cycles spent with `IP` inside the main-loop wait for vblank.
     Find that loop from a MAME trace (the memory note says the main loop runs at
     WRAM 0x100004e0; confirm the exact PC range with the trace below).
B. MAME reference with `./sysfl` + autoboot Lua, headless
   (`-video none -sound none -nothrottle`), same moments of the game:
   - instructions per frame and idle-loop instructions per frame. Use
     `manager.machine.debugger:command("trace <file>,:maincpu")` for one frame at a
     few points (attract ~frame 600, race ~frame 1400 of `speed1.inp` playback:
     `-input_directory <dir> -playback speed1.inp`), then count lines and lines
     whose PC is in the idle loop. Needs `-debug -debugger none`. Keep notifier
     handles in globals (Lua GC unsubscribes otherwise).
   - cycles per frame at 20 MHz = 20e6/59.659 ~ 335k. Busy fraction =
     (non-idle instructions * MAME cycles/instr) / 335k.
C. Report: RTL cen/instruction (overall and per class), RTL busy fraction at 46
   MHz, projected at 20 MHz, vs MAME's busy fraction. This tells how much speedup
   is needed (expected: ~2.3x or more).

## Phase 1 - overlap fetch with execute (biggest, cheapest win)

- Execute register-only instructions (REG/COBR/CTRL classes with no memory
  access) in the same cen as an icache-hit fetch: the decoder already sees
  `icd_q` in `FETCH` (`dec_in`, L96). Target: 1 cen per simple instruction on a
  hit. Keep `EXE` for everything else.
- Add a 2-word prefetch queue (README TODO #3): while an instruction executes or
  waits on data, fetch `IP+4`/`IP+8` if the bus is idle. Flush on taken
  branch/call/ret/interrupt/IAC.
- Acceptance: `go.sh` PASS; Phase 0 counters show cen/instruction dropping; full
  sim 400 frames reaches the same boot milestones (`jt960 milestone` lines in the
  log) no later than before.

## Phase 2 - real-size instruction cache

STATUS: a parametric instruction cache is already in jt960 (`ICACHE_BLK`,
default 1kB in one M10K, word fills, 1-clk registered hit). What remains here is
line fills (4 words per miss) and folding the 1-clk RAM latency into Phase 1's
prefetch. A data cache is NOT in jt960 yet: it needs a `cacheable` input from the
system (shared RAM with the C75, video RAM and MMRs must never be cached) and a
write policy; propose `DCACHE_KB` 0/1/2/4 with write-through, default 0.

- Grow the icache to 512 B (128 words) like the KA: direct-mapped, 4-word
  (16-byte) lines filled from the `main` bus. Keep invalidate-on-write (a store
  to a cached word) and IAC 0x89 invalidate-all.
- Data in block RAM (infer a simple dual-port RAM with synchronous read, keep it
  in jt960, not in mem.yaml; the tag array may be registers). Budget: 512 B data
  = one M10K.
- Line fill: 4 sequential 32-bit reads (or 2 if `JTFRAME_BA0_LEN=64` is set for
  64-bit bursts; that macro also doubles the `main` cache line). Measure both.
- Acceptance: icache hit rate in the idle loop and main loop ~100%; fetch-wait
  cycles per frame drop to near zero outside cold misses.

## Phase 3 - data side

- Work RAM: consider making `wram` a 32-bit rw bus in mem.yaml (one SDRAM access
  per word instead of two) and teach the funnel to pass 32-bit WRAM accesses in
  one go. Check `jtframe` supports 32-bit rw buses on that bank; if not, keep 16.
- Trim the funnel: no SETUP cycle for back-to-back accesses, BRAM reads in 1 cen
  when the address is registered early.
- Frame cache: copy 2 words per cen (two LUT-RAM ports) or overlap copying with
  the next instruction fetch. Silicon does a call in ~9 cycles.
- Acceptance: data-wait and call/ret classes in the counters shrink; no regression
  in `go.sh`.

## Phase 4 - align the clock

- Lower `cpu_cen` in `mem.yaml` step by step: 46 -> 32 -> 24 -> 20 MHz. At each
  step run 400 frames (boot) and the 2700-frame `speed1_fast.cab`.
- At 20 MHz the RTL idle fraction per frame must be >= MAME's at the same scenes.
  If it is lower, go back to the phase with the largest remaining wait class.
- The C75 handshake is timing sensitive: watch that coins still register (log
  lines `coin inserted`, credits reach 3/3 = the game starts; `VSTAT` rows keep
  going) and that the jt37702 keeps taking its per-frame IRQs.
- Update `mem.yaml` comments to say 20 MHz = real, drop the bring-up note.

## Verification checklist (every phase)

1. `cores/sysfl/ver/i960/go.sh` -> PASS.
2. 400-frame full sim: boot milestones reached, no `halted`.
3. 2700-frame `speed1_fast.cab`: 3 `coin inserted` lines, the game starts
   (car select ~frame 700, race ~850+), `VSTAT` c123/roz misses stay ~0.
4. Produce the MP4 with `cores/sysfl/ver/speedrcr/mkmp4.sh test.mp4
   ../../doc/<name>.mp4` (1:1, yuv444p, crf 18; never scale/filter) for the user
   to grade. Do not judge frames yourself.
5. Report per phase: the Phase 0 counter table before/after and the projected
   busy fraction at 20 MHz vs MAME.

## Prior art: Sega Model 2 i960KB

https://github.com/alphanu1/sega-model2-mister/tree/main/rtl/cpu/i960 (GPL-3.0,
MAME-transcribed semantics like jt960). REFERENCE ONLY: do not copy its code,
build jt960's own blocks in jt style (cen/bus_ok, jtframe modules). Read
`i960_icache.sv`, the prefetch block in `i960_top.sv` (~L900-1090) and
`HANDOFF.md` before Phase 1.
- `i960_icache.sv`: 512 B direct-mapped, 16 B lines, 4-word burst fill,
  demand vs speculative requests (only a demand may abort a fill), `vaddr` tags
  each `valid`. Same shape as our Phase 2 target; use it to check design
  decisions, not as a drop-in.
- Their measured CPI is 14.97 with I-cache + sequential prefetch + D-cache;
  almost all remaining fetch misses are mispredicted branches. Their fixes:
  predict the branch target at decode (displacement is in the instruction) and
  single-cycle cache hits (~20% CPI). Do both in Phase 1.
- Their conclusion: a multi-cycle FSM needs 123-164 MHz to reach silicon i960
  throughput. Our target is MAME's per-frame idle time, not silicon CPI; if
  Phase 0 shows Phases 1-3 cannot get there at 20 MHz, the next step is a 2-3
  stage pipeline (fetch | decode+regread | execute), not more FSM tuning.

## Out of scope

- The C75 (jt37702) has the same issue (runs at full clk instead of XIN
  16.128 MHz); separate task.
- The 96 MHz (`JTFRAME_SDRAM96`) move comes after this plan.
