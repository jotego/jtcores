# Rastan SOUND ERROR — investigation status (branch pc060-fiddling)

Issue: https://github.com/jotego/jtcores/issues/1215 (sword sound; service menu shows
SOUND ERROR). Real MiSTer hardware fails; this branch's sim now fails the same way.

## Baseline on this branch (committed)
* `a5f7cc37f` phase-lock: 68k dtack `num/den = 231/1541` on clk48 = 8.0028 MHz,
  exactly 2x the Z80's cen4. Was 1/6 = 8.898 MHz (11% fast, ratio 2.22 not 2.00).
  Board: both CPUs off one 16 MHz XTAL (schematics: PC060 MCLK=8M, SCLK=4M).
* `132465f70` work RAM to BRAM: 68k 16 kB work RAM (0x10c000) -> `bram: wram`
  (jtframe_ram16 8Kx16, `wram_we = ~main_dsn & {2{ram_cs & ~main_rnw}}`). VRAM stays
  in SDRAM (tilemaps read it back). Kills wait states/RECOVERY bursts on the 68k.
  COST: 16 of 66 M9K on MiST/SiDi — needs a fit check.

**Since the BRAM move the sim reproduces the hardware failure** (before: sim passed,
HW failed). Debug loop is now ~60 s instead of a build.

## The test protocol (verified against MAME + ROM disassembly)
Walking-bit echo: main sends `F0 00 00 01 02 04 08 10 20 40 80 F0` (x2, then EF).
**The reply lags by one command**: SEND 02 -> RECV 01 ... SEND 80 -> RECV 40.
Any core replying with the CURRENT command fails. Commands `EE/EF` write CIU submode 4
= the PC060HA AMP/MUTE pin (schem pin 18 -> MUTE 9-B5); MAME no-ops it.

## Sound CPU internals (from b04-19.49, SHA matches MAME)
* NMI `$0066`: read 2 nibbles, `call $00C0` = **enqueue only** (<F0 -> ring at `$8F02`
  wptr `$8F00` rptr `$8F01`; F0..FE -> 2nd queue `$8E82[32]` via `$00E9`).
* Test-mode loop `$01AB` (free-running, NOT the 16.4 ms YM timer):
  YM CT write via `$158C` (busy-waits) -> `$0254` **drains the whole queue**
  (`$8F28 = cmd` per entry, intermediate echoes dropped by design) -> `ei` ->
  `$01C2`: if `$8F27` bit0 set, posts `($8F28)` unconditionally; else `$01DC`
  posts E0 but **skips if status bit2 still set**.
* Second reply routine `$0439` (ix-based): posts `(ix+3)`, then **blocks** polling
  status bit2 until the main consumes. This is the spin-lock seen after failure.

## Failing signature (traced, this baseline)
First 1-2 exchanges lag correctly, then the reply becomes = CURRENT command and stays
there. Concretely: echo(02) never got posted; when the loop ran, the queue held
[02,04], the drain overwrote `$8F28`, one echo was swallowed, the pipeline drained to
the "no-lag" stable state. After the main declares SOUND ERROR it stops consuming and
the sound is left spin-locked reading status=4.

## Measurements (all on this baseline)
* YM2151 timer: driver programs CLKA=0 (regs 10/11=0, reg14=0x15) -> 16.384 ms;
  jt51 delivers 16.378 ms. **jt51 timer is correct.**
* jt51 busy flag: 32 synth cycles = 8 us. Not a bottleneck.
* Z80 SDRAM fetch stalls: **1-2% of wall time**. NOT the slowdown.
  => a `cache_size` on the snd bus can recover at most ~2%.
* Sound loop period between echo posts: **median 314 us** (min 118, max 4270).
  ~1250 Z80 cycles/pass — plausibly the genuine cost of the loop body.
* **MAME's loop measured the same way: ~260 us/pass** (257 $A001 writes/frame / 4).
  => our loop pace is FINE (~20% slower, same order). The race-model fork resolved:
  my pass-condition model is wrong; see open question 1.
* MAME ring queue depth reaches 3 (whole run) and still passes.

## Ruled out (each still shows SOUND ERROR / no change)
* CIU mode-4/5/6 side effects on reads + master/slave split (submode 4 = mute, not
  nmi_en). Real MAME divergence, worth keeping for accuracy, but not the bug —
  retested on the honest baseline.
* jt51 timer, jt51 busy, cen4/cen_pcm rates, RECOVERY(0), CDC single-clock move,
  direct-status rewrite (failed deterministically — had a same-cycle set/clear
  collision bug, never fixed+retested), 68k clock alone, CIU 8M/4M cen gating
  (tested only on the pre-BRAM baseline when the sim was not representative).

## OPEN QUESTIONS (start here next time)
0. ~~F0 toggle lead~~ TESTED AND DEAD: tapped $8F27/$8F28 in both harnesses.
   **Ours is IDENTICAL to MAME**: 8f27<=01, 8f28 stores 00 00 01 02 04 08 10 20 40 80
   one per command in order, 8f27<=00/01 between passes, 8f27<=00 at the end.
   The sound CPU's internal state is byte-identical to MAME through the whole test.
   TIMING NOTE (ours, with ticks): 8f28<=02 and <=04 land 54us apart = one drain pass
   ate two commands = echo(02) swallowed. MAME (no timestamps possible) must not do
   this, since every echo reaches the main. So the ONLY remaining difference is the
   INTERLEAVING of the sound's posts vs the main's reads. Everything inside the
   sound CPU is exonerated.
   REMAINING PUZZLE (write-up of the contradiction): the $01AB loop drains BEFORE it
   posts, so with any loop period the freshly-drained value should be what gets
   posted, and lag-1 should be impossible -- yet MAME delivers lag-1. Either the
   $01AB/$01C2 model is still wrong (more disassembly needed: what runs between
   $01C0's jr target and $01AB; the E0-path interleave), or MAME's lag-1 is purely
   a scheduler-quantum artifact and the REAL PCB passes via a mechanism neither we
   nor MAME reproduce (e.g. main-side poll count / timeout constants). Next probe:
   in OUR sim, log the main's poll count per exchange AND check ($01DC) E0 posts
   interleaving; consider tracing the main 68k's test routine (0x3F084 caller) to
   find what value/count it actually compares against.
   (old lead text below for reference)
   **the F0 toggle.** `$03E5` dispatches F0-FE via
   the table at `$041B`. F0 -> `$03F7`, which **TOGGLES `$8F27` bit0** (test mode).
   The test stream is `F0 ...data... F0` twice, so the flag flips on/off/on/off and
   must stay ordered with the data commands. But the NMI handler feeds TWO queues
   (`$8F02` data ring; `$8E82[32]` via `$00E9` — recheck: `$00B0 call $00E9` may run
   for EVERY command) drained by different paths (`$0254` vs `$0298->$03E5`). If the
   toggle is processed early/late relative to the data commands, the reply path flips
   mid-stream between `$01C9` (unconditional echo) and `$01DC` (E0/skip) — matching
   our exact signature (first exchanges ok, then wrong forever). **Next: RAM-tap
   `$8F27` writes alongside the comm stream in our sim AND in MAME (LUA tap), and
   compare where each toggle lands relative to the data commands.** Also re-verify
   the `$0066-$00B0` NMI-handler decode (who exactly goes into which queue).
1. **The race model has a hole**: if the loop is ~314 us on real HW too, the main
   (which re-polls ~10 us after sending) should also read the fresh echo there and
   fail. It doesn't. So the test-time reply path is probably NOT `$01C2/$01C9` —
   suspects: `$8F27` semantics inverted, or the ix-based `$0439` routine is the one
   replying during the test (it blocks, so every echo is delivered and lag is
   structural). Disassemble `$0420-$0478` callers and `$8F27` writers.
2. ~~PC060 halves at 8M/4M~~ RETESTED on the honest baseline (cen8m=231/1541 on
   clk48, cen_s=cen4, units cen-gated): **still SOUND ERROR**. Ruled out as the bug;
   keep as an accuracy improvement if desired. The consistent interleaving bias at
   the exchange moment (MAME/PCB read the OLD echo, we read the NEW one, ~100% of
   the time, with equal loop rates) remains unexplained -> question 1 is the lead.
3. ~~Compare loop period in MAME~~ DONE: ~260 us. The race model is definitely
   wrong (see 1). Note MAME cannot arbitrate the interleaving question anyway: its
   scheduler().synchronize() at every master send enforces lag-1 artificially.
   The next reference has to be the ROM's own logic ($8F27 semantics, $0439 path).

## Reproducing
Docker `jotego/simulator:arm64` (host has no verilator):
```
docker run --rm -v "$ROOT:$ROOT" -v "/path/zips:/root/.mame/roms:ro" -w "$ROOT" \
  --entrypoint bash jotego/simulator:arm64 -c "cd '$ROOT'; source setprj.sh; \
  cd \$JTROOT/cores/rastan/ver/game; \
  jtsim -verilator -setname rastan -d JTFRAME_SIM_VIDEO -dipsw 0000 -video 100 \
        -inputs ../rastan/service.cab"
```
`SOUND ERROR` legible in `frames/frame_00129.png`. `-d SND_TRACE`
(+`-d SND_TRACE_START=25000000`) enables the comm/YM/stall trace in jtrastan_snd.v.
MAME reference: SUBTARGET build + LUA taps — see `mame-rastan-lua-trace` notes;
never call `device.state[]`/`machine.time`/`flush` inside a tap (segfaults 0.288).

## BUSY-FLAG SENSITIVITY RESULT (the first sim PASS on the honest baseline)
jt51_mmr.v busy duration probe (rastan service test, honest baseline, all else equal):
32 cycles (stock) = SOUND ERROR ; 64 = SOUND ERROR ; **128 = SOUND CODE:00 (PASS)**.
Mechanism: the 16.4ms music-tick handler is a chain of YM busy-waits; its length sets
the drain->post stretched-window duty; between 64 and 128 the phase lock flips.
CAVEATS BEFORE VICTORY (learned the hard way this session):
1. Which cen clocks jt51_mmr? (cen vs cen_p1) -> stock 32 counts may be 8 or 16us.
   Real YM2151 busy is commonly held to be ~64 phiM = 16us -> 128 might be a 4x
   overcorrection that happens to flip the lock, not accuracy. Check ymfm/Nuked-OPM
   and the datasheet; measure a real chip if possible.
2. Apply the lesson of the phase-lock false victory: re-test at the WRONG 68k clock
   (1/6) — if it only passes at one operating point it may still be luck.
3. Hardware build required; sim passed once before and hardware said no.
4. jt51 is a submodule — this edit is in modules/jt51 working tree, uncommitted.
If 128 survives 1-3, this likely also affects music pacing = possibly the original
sword-sound complaint. Coordinate with jotego before changing jt51 upstream.

## Luck test result (busy=128)
busy=128 + correct 2:1 phase lock: PASS. busy=128 + wrong 68k clock (1/6=8.898MHz):
SOUND ERROR. So the pass needs BOTH. Two readings: (a) still operating-point luck;
(b) legitimately timing-sensitive protocol -- an 11% CPU error is not a fair
robustness test, the board never has it. Note jt51_mmr runs on cen_p1 (2MHz): stock
32 counts = 16us which MATCHES the commonly-cited real busy (~64 phiM); our 128 =
64us = 4x real -> likely an overcorrection that flips the lock, not accuracy.
Hardware decides. Build config = phase-lock (231/1541) + BRAM + jt51 busy 128.

## Minimality bisection (all on phase-lock + BRAM baseline)
busy=128 + stock pc060: ERROR. busy=128 + mode-4/MASTER fix only: ERROR.
busy=128 + MCLK/SCLK cen-gating only: ERROR. busy=128 + BOTH: **PASS** (verified
twice: with local frac_cen and with cpu_cen plumbing; and re-verified after
stripping all instrumentation). Minimal passing set = phase-lock + BRAM +
jt51 busy 128 + pc060 mode-4 write-qualified MASTER split + pc060 MCLK/SCLK gating
(fed by the 68k's own cpu_cen). NOTHING is removable. Double edge: also means the
pass lives at the intersection of three timing-ish changes -> hardware must decide.

## REVIEW + MEASUREMENTS (branch pc060-lock-no-bram)
Adversarial review (independent model) findings, all verified:
- The phase-lock/two-crystal theory SELF-CONTRADICTS: the constant-NMI-delay failure
  implies the main is COUPLED to the sound's posts; coupling absorbs crystal drift.
- MEASURED: inter-SEND intervals median 0.313 ms = one sound-loop period (not 16.7 ms)
  -> the main is handshake-slaved to the sound's posts. Frame-pacing premise dead.
- The cen dither idea is quantitatively dead (30-600x too little phase diffusion at
  honest amplitude; audible wow at effective amplitude; LFSR deterministic anyway).
- CRITICAL UNSOLVED: under the coupled model, reading the CURRENT echo is structural
  (loop drains before posting), so NEITHER model explains why busy-stretch=64us flips
  the sim to PASS, nor how the real PCB/MAME produce lag-1 at all. Everything
  converges on the REPLY-PATH MODEL BEING WRONG.
Poll-count table (honest baseline, per exchange): failing exchanges are machine-regular
(3 consume-polls, 21 bit2-polls, 274 us send->recv); the one passing exchange rode a
4.2 ms IRQ stall (24/10 consume-polls, 387 bit2-polls).
NEXT (the only lead left, was open question 1 all along): finish the sound-firmware
reply-path disassembly -- $8F27 readers/semantics, the blocking $0439 ix-routine
(callers $08F9/$1A65), and the loop entry between $01C0's jr target and $01AB.
The correct model must explain: PCB pass, MAME lag-1, our CURRENT-echo, busy-stretch
flip, NMI-delay non-effect -- all five.
