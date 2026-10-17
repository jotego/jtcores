# YM2151 PCB validation

Issue: http://gitea.jotego.es/jotego/jtcores/issues/143

Full objective: validate jt51 against the Diet Go Go YM2151, including timers,
phase generation, envelope generation, LFO and other observable subsystems.
Bring-up alone does not complete this issue.

1. Establish PicoROM P28 programming, readback and a reset-free sound CPU monitor.
2. Establish Chameleon96 programming, finite raw capture and verified transfer.
3. Qualify serial bit timing, word framing, data polarity and channel mapping with
   silence, a nonzero tone and independent left/right controls. Preserve raw data.
4. Extend capture to long decoded measurements without PC transfer stalls.
5. Apply identical register programs to hardware and jt51. Compare timer periods
   and flags; PG key codes/fractions/multipliers/detune; EG rates/levels/key scaling;
   LFO waveforms/rates/AM/PM; noise, algorithms, feedback, clipping and reset state.
6. Investigate discrepancies, make justified jt51 fixes and rerun affected tests.
7. Commit/push reproducible source and measurement documentation; retain raw data
   locally, report exact validated coverage and close only after the full audit.

## Current evidence (2026-10-17)

- Branch `jtcores-143`, unrelated user module changes untouched.
- PicoROM `E66550A14758A021`: P28_27C512_70ns. Initial image was 64 KiB of FF.
  Backed up before changes. Built/installed existing diagnostic firmware from
  PicoROM commit c2fa947d8c1ca8a1e7cb0b9b4b4dcd331aff5fff for the P28 target.
  Device reports diagnostic version jtkcpu-1.6 and correct P28 configuration.
- Monitor copies itself to sound RAM after a stack-free test of all 8 KiB RAM.
  MPR1=F8 (RAM), MPR2=88 (YM2151), MPR3=01 (ROM control/comms), MPR4=02
  (ROM command table). Host writes/verifies table before generation/complement.
- Assembled monitor passes MAME HuC6280 execution, both RAM patterns, boot frame,
  timer A overflow, flag reset and two successive command generations. MAME's
  register writes are checked, not merely the assembly syntax.
- Physical CPU boot frame B0 00 00 arrived immediately after verified upload.
  No requested PCB power cycle was necessary; this accidental initial entry is
  not a guarantee that arbitrary future ROM installs can start without reset.
- Physical live replies: D0 01 01 (timer A), D0 02 00 (clear), D0 03 02 (timer B),
  D0 04 00 (tone), D0 05 00 (silence). Communication event records contain exactly
  these responses, no dropped bytes and no second boot frame.
- Chameleon USB SSH at 192.168.96.96 works with retained host pin. Linux boot ID
  3e876240-d0e5-41cf-b52d-9c2d2a303a0c unchanged during FPGA runtime programming.
  Existing protocol 960102 capture image loaded; PRNG all 32768 words verified.
  Initial, tone and silence raw files have matching HPS/PC SHA256.
- Raw bits 0/1 are staggered periodic pulses (about 55.94 kHz each), bit 2 changes
  with tone, bit 3 is static. Provisional SH/SH/SO identity inferred from signals;
  user confirmed the open-drain inverting adapter; post-reset pan controls now
  qualify latch channel 0 as right and channel 1 as left.
- At this initial milestone, timers had functional flag smoke tests only, not
  period comparison against jt51, and raw audio was not yet qualified as decoded
  samples. Later decoder and phase milestones qualify the audio path below.

## Decoder milestone

- Added standalone task-local Yamaha sampler and mode 3, protocol 960103. It
  estimates bit centers from alternating SH boundaries; no fourth clock wire is
  required for the current harness. Full serial words and their dummy bits survive.
- Synthetic simunit covers packing, both channels, fractional 55/56-clock cells,
  inversion, reset/clear and malformed/missing strobes. Capture-control simunit
  covers all original PRNG/raw/PCM modes and new Yamaha acquisition/readout.
- Saved silence/tone/high/mid/mid2 raw traces replayed through RTL match every word
  from the independent Go decoder. External-file replay is now a standalone
  Verilator flow (not a CI simunit); the current high recording passes it too.
- Final Quartus build: 328 ALMs, 539 registers, 64 M10Ks, worst setup +1.873 ns,
  worst hold +0.122 ns; unconstrained clocks/input/output paths all zero. Only
  warning is subscription-only LogicLock. RBF SHA256:
  bd58fbab75d092d721452b9ff23203a098e362032ca5dd1b052de8532fc14a2b.
- Runtime-loaded successfully without changing HPS boot ID. Tools are isolated
  under `/home/root/jtcores143`, firmware named c96-yamaha; original runtime
  capture app and images preserved. Full 32768-word PRNG regression passed.
- A mode-3 physical capture has 16384 samples/channel, no framing errors and
  valid exponent fields; both channels swing -8176..8160. This capture used
  pre-reset register state and KC=00. Latest interval yields ~17.28 Hz.
- Same full tone program produces ~440 Hz in MAME and jt51 (jt51 at commit
  985a573dcfc1ff135553a39f7eae21d18ba57cbe), with native sample cadence 64 clocks.
  Physical short captures at KC=4A/4C looked unexpectedly slow, while KC=7C gave
  ~3729.84 Hz. Do not classify this as a jt51 mismatch yet: establish a known
  YM reset state and use long captures first. This has now been done: see the
  post-reset milestone below. The old bounded boot poll has finished.

## Post-reset phase milestone

- User power-cycled the PCB; fresh monitor boot frame `B0 2A 00` received.
  Chameleon96 and PicoROM remained running. All 17 original cases repeat.
- User reports master clock 32.22 MHz / 9, nominal sample rate 55,937.5 Hz;
  on-pin frequency 3.57–3.58 MHz with 0.01 MHz tolerance. Raw SH timing agrees.
- 243 independent full programs cover KC, KF, DT1, DT2 and multiplier/base
  interactions. jt51 and an independent external Nuked-OPM oracle agree in
  every case. The PCB has 129 matches and 114 effective increments lower by 8192.
- The complete pattern fits a missing bit-13 contribution when MUL bit0 is set;
  it is not a general mask after multiplication. Do not emulate this in jt51
  without separating chip behavior from control/capture setup.
- Accepted captures have verified transfer hashes, zero framing errors, nonzero
  samples of both signs and low sine-fit residual. Two failing framing captures
  are retained and excluded; the transient disturbance remains unexplained.
- Independent pan-only programs qualify stereo ownership and exact controlled
  silence. See [phase-measurements.md](phase-measurements.md) for exact coverage,
  inference limits, waveform-fit method and local evidence locations.
