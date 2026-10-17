# Post-reset phase measurements

Diet Go Go YM2151, 2026-10-17; issue jtcores #143 remains open.
No jt51 implementation changes have been made in response to these measurements.

## Known setup

- PicoROM P28 resident monitor and readback-verified bytecode; each command has a
  generation/complement handshake and a three-byte CPU completion reply.
- The user power-cycled the PCB with PicoROM USB and Chameleon96 still powered.
  The fresh monitor boot reply was `B0 2A 00`. The full 17-case initial matrix
  repeated its pre-reset result after this reboot.
- YM master clock: user reports 32.22 MHz / 9 = 3.58 MHz. On-pin measurement
  is 3.57–3.58 MHz with 0.01 MHz tolerance. Native sample rate is nominally
  55,937.5 Hz; independent raw SH measurements give about 55,937 Hz.
- User confirmed open-drain inverters feeding the 1.8 V inputs. Both hardware
  and independent raw decoders apply input inversion before edge/data decoding.
  Package marking reported by the user: `9223 EAEG`.
- Only a single unmodulated operator is audible, algorithm 7, TL=0, AR=31,
  D1R=D2R=0, no feedback/LFO/noise. Each case starts with complete initialization.
- jt51 reference: submodule commit `985a573dcfc1ff135553a39f7eae21d18ba57cbe`.
  Independent external Nuked-OPM reference: commit
  `a0ab44be60cb28b68431779829454ddf3284f272`.

## Method and limits

Every accepted hardware recording has 16,384 samples/channel, no framing errors,
valid serial exponent fields and matching HPS/PC SHA256. The Go fitter estimates
sine phase versus native sample index, then rounds the slope to a 20-bit phase
increment. All 243 accepted fits have RMS residual between 0.001006 and 0.002055
radians. They include positive and negative nonzero samples. Synthetic quantized
sines and both model outputs independently exercise this method.

These are **effective increments inferred from output**, within the controlled
positive-frequency sine model. They do not directly read the chip's internal
phase accumulator. Absolute phase and transient timing are not aligned. A clock
calibration change affects reported Hz but cannot change the inferred increment.

The two software references agree on every expected increment. For Nuked-OPM,
internal increment and every modular accumulator step also agree; its native
cadence is 64 master clocks. The external implementation was not modified or
copied into this repository; only a public-API wrapper is maintained here.

## Coverage and observations

The reproducible generator emits 243 complete programs:

| Sweep | Cases | Exact matches | PCB minus reference |
|---|---:|---:|---|
| All KC, KF=0, MUL=1 | 128 | 96 | 32 cases: -8192 |
| All KF at KC=4A, MUL=1 | 64 | 0 | All: -8192 |
| All DT1 at KC=4A, MUL=1 | 8 | 0 | All: -8192 |
| All DT2 at KC=40, MUL=1 | 4 | 3 | One: -8192 |
| MUL=0..15 at KC=40 | 16 | 16 | All: 0 |
| MUL=0..10 at KC=4A | 11 | 6 | Five odd multipliers: -8192 |
| MUL=0..7 at KC=50 | 8 | 4 | Four odd multipliers: -8192 |
| MUL=0..3 at KC=60 | 4 | 4 | All: 0 |
| **Total** | **243** | **129** | **114 cases: -8192** |

The following relation describes all measured cases. Let `base` be the expected
post-detune increment before multiplication, and `m` the MUL register:

```
MUL=0:       effective = base >> 1
MUL>0 even:  effective = base * m
MUL>0 odd:   effective = base * m - (base & 0x2000)
```

This is a hypothesis for localizing the observation, not a proposed jt51 change.
It looks like a missing bit-13 contribution from the multiplier's least
significant partial product. A blanket bit-13 mask after multiplication is
**disproved** by the KC=40 multiplier sweep. For example:

| KC | MUL | Reference increment | PCB effective increment |
|---|---:|---:|---:|
| 40 | 1 | 5196 | 5196 |
| 40 | 2 | 10392 | 10392 |
| 4A | 0 | 4124 | 4124 |
| 4A | 1 | 8248 | 56 |
| 4A | 2 | 16496 | 16496 |
| 4A | 3 | 24744 | 16552 |
| 4A | 4 | 32992 | 32992 |
| 50 | 1 | 10392 | 2200 |
| 50 | 2 | 20784 | 20784 |
| 50 | 3 | 31176 | 22984 |

At the nominal clock, increment 8248 gives 439.9991 Hz and increment 56 gives
2.9874 Hz. The package/master-clock information does not explain this selective
pattern. Chip behavior, bus/control timing and physical capture isolation still
need to be separated before classifying a defect. Before reset, the slow KC=4A
result was also reproduced on all four operators of channel 0 and on C2 of
channels 1, 4 and 7; repeated KC writes and TEST-bit reset pulses did not clear it.

## Panning and capture qualification

Four additional post-reset programs use KC=40 and select register 20 pan masks
87, 47, C7, 07. Mask 47 produces a nonzero sine only on latch0; mask 87 only on
latch1; C7 enables both and 07 produces exact zero on both. All four transfers
pass hash/framing checks and controlled nonzero/silent observations.

The original helper and filenames called 87 left and 47 right. That was a naming
error, corrected after direct visual review of Yamaha application notes
section 2.1.8 ACC (printed 14/PDF 15): bit 7 enables RIGHT, bit 6 LEFT. Figure 2.17
(printed 21/PDF 22) independently labels SH1 RIGHT and SH2 LEFT. Therefore actual
latch0 is left and latch1 right for this capture wiring. `left.bin/.cap` retain
the original 87 bytes/name and `right.bin/.cap` retain 47; no historical data or
hash is rewritten. The both-pan PG/EG/LFO comparisons are unaffected. Future
built-in tone-left/tone-right programs use the corrected primary bit meanings.

The first expanded KC=07 capture reported 257 framing errors; an immediate
separate diagnostic repeat reported 567. Both are retained and excluded. A later
repeat and the accepted campaign retry were clean. Short raw recordings at
100 MHz and 12.5 MHz independently decoded the same signal with alternating SH
edges and nominal sample timing. The transient framing disturbance is unresolved;
successful captures are never substituted silently for failed evidence.

## Local artifacts and next steps

- `artifacts/post-reset`: boot-era tone, repeated initial 17-case comparison,
  raw timing diagnostics and failed/clean framing captures.
- `artifacts/pg-expanded`: first 220 programs, per-case physical captures and
  command/transfer logs, jt51 CSVs and comparisons.
- `artifacts/pg-cross`: 23 multiplier/base interaction cases and both references.
- `artifacts/opm-reference`: original/expanded independent oracle, interface
  review, internal increment and phase-step checks.
- `artifacts/pg-all-comparison.{json,csv}`: combined 243-case comparison, hashes
  and a checked prediction of the missing-contribution hypothesis.
- `artifacts/pan-post-reset`: four complete programs, captures and channel stats.

Next: isolate the pitch discrepancy without changing jt51 to reproduce an
unclassified hardware/setup anomaly. Timer periods and event-aligned EG/LFO,
noise, algorithms, feedback, clipping and reset behavior remain to be validated.
