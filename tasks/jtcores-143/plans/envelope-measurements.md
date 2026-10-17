# Native envelope measurements

Diet Go Go direct YM2151 output, 2026-10-17. Production jt51 remains frozen at
`985a573dcfc1ff135553a39f7eae21d18ba57cbe`. No RTL or candidate patch was created.
The full audit is incomplete; implementation remains deferred under the user's
[jt51 #3 instruction](http://gitea.jotego.es/jotego/jt51/issues/3).

## Qualified acquisition and comparison

The new event workflow executes a complete initialization with all keys off,
waits 50 ms, arms the FPGA recorder, then submits a short event program through
the resident monitor. The event delays 256 CPU-loop counts, keys on C2 and
returns. Captures retain 16,384 native frames/channel, approximately 293 ms at
the nominal 55,937.5 Hz sample rate. USB/SSH timing is recorded but is not a
chip-clock key-on timestamp. Silent pretrigger samples are verified in each
attack recording rather than inferred from the host command order.

`scripts/capture-event.py` keeps one PicoROM client and the monitor lock for
the entire acquisition. It verifies device/monitor identities, generation
handshakes, remaining marker budget, capture ownership, header identity/count,
transfer SHA256 and decoder checks. Each prefix retains exact INIT/EVENT bytes,
their hashes, command replies, recorder/tool/boot identities, capture header,
host timing bounds, raw capture, decoded CSV and a success/failure manifest.
It stops rather than rerunning a failed stimulus. Output names are exclusive.

Both model wrappers now record before and throughout EVENT execution. Their
exclusive `.events.csv` files identify capture start and register-data submission
or strobe clocks. Model INIT is followed by 4096 master clocks of settling;
physical conditioning uses the separate 50 ms pause. Model delay bytecodes still
use an explicitly approximate 32 master clocks/count, so absolute onset timing
is not compared. Legacy steady recordings remain byte-identical in both models.
Event tests verify silent pretrigger, native 64-clock cadence, recording during
long bytecode delays, finite sample limits and retained later event writes.

Nine preliminary AR31/20/18 recordings at C2 MUL2 qualified pretrigger and
transient capture. The main fixtures use KC=4A, KF=0, C2 MUL8, algorithm 7,
TL=0, no LFO/noise/feedback. This even-multiplier pitch passed the independent
PG matrix: effective increment 65984, nominal carrier about 3520 Hz.

## Fixed amplitude features and limits

`host/envelope.go` projects PCM onto sine, cosine and a DC term at that fixed
carrier frequency. Its 32-sample window spans about two cycles, with an
eight-sample hop. Window duration is **0.572 ms**. Frequency and window size
are fixed across the main matrix; no per-case waveform correlation or filtering
is fitted to conceal onset differences. Linear and nonlinear synthetic attacks
with several carrier phases validate threshold durations within a window.
Wrong-carrier, unfinished, silent and missing-pretrigger inputs are qualified
separately. CSV parsing checks finite values and consecutive sample indices.

For isolated attacks, the reported feature is the interval between 10% and 90%
of the final-quarter median amplitude. A measured state requires a final-quarter
relative amplitude span at most 1% and carrier residual at most 2%. The final
level is an estimate; this relative-flatness gate does not prove the correct
absolute TL/decay level. Absolute levels are compared independently below.

The initial feature comparison uses the observed range of three physical runs,
widened by two projection-window durations for the two compared estimates.
This is a conservative windowed-feature comparison, not a confidence interval
or a sample-identity proof. At the fastest rates the observed interval is mostly
window blur around a step; sub-window attack timing remains unresolved. The
AR12 physical repeat range is wider than a window, demonstrating why one modeled
event phase is not a physical phase measurement.

Use `-curve-only` for decay/hold recordings. It retains projected level/residual
statistics and optional amplitude CSV without scoring an attack against an
inappropriate final level. Earlier exploratory hold JSON contains unused attack
fields; the hold conclusions use only amplitude curves and final-level estimates.

## AR12–31 at KS0

Twenty AR settings were independently initialized three times: **60 physical
transients**. Every accepted recording is nonzero in both signs, with verified
transfer hash, valid serial exponents and zero framing errors. Both models ran
the identical INIT/EVENT bytes. Nineteen settings are consistent within the
declared feature band; AR14 is a large mismatch.

| AR | PCB 10–90% feature range, ms | jt51, ms | Independent OPM, ms |
|---|---:|---:|---:|
| 12 | 90.684–92.439 | 90.709 | 90.730 |
| 13 | 68.321–68.401 | 68.332 | 68.351 |
| 14 | 46.012–46.055 | 0.472 | 46.026 |
| 18 | 11.308–11.424 | 11.395 | 11.363 |
| 20 | 5.636–5.701 | 5.690 | 5.616 |
| 26 | 0.844 | 0.808 | 0.839 |
| 31 | 0.458–0.502 | 0.483 | 0.467 |

AR31 and the jt51 AR14 result are steps at this resolution; the numbers near
0.5 ms describe the projection window's response, not a gradual 0.5 ms attack.
The complete table is `artifacts/envelope-native/attack-comparison.{json,csv}`.
The standalone PNG/PDF plot preserves the full sweep and an onset-aligned raw
RMS view; onset alignment illustrates shape and does not establish key-on latency.
The [attack comparison figure](http://gitea.jotego.es/attachments/022dadde-7b54-4be2-8ea6-afa84355bf90)
is attached to the issue; intervals below 0.572 ms remain window-limited.

## Confirmed instant-attack boundary

The AR14 discrepancy survives four exact fresh-process repeats, sixteen bus
phases, fifteen event delays, six additional settling lengths and three prior
voice histories. Every INIT was independently decoded to check the requested
register values. Read-only internal instrumentation produces byte-identical
output to the uninstrumented prefix.

Trace evidence identifies the current jt51 path: effective rate 30 or 31 is
shifted to 15, and the ATTACK update's comparison against literal `5'hf` sets
attenuation directly to zero at the first eligible envelope update. This is
diagnosis of existing logic, not a proposed patch or replacement architecture.

Changing AR/KS reaches this same path in four separately measured configurations:

| AR | KS | Effective rate | PCB attack feature range, ms |
|---|---:|---:|---:|
| 14 | 0 | 30 | 46.012–46.055 |
| 13 | 1 | 30 | 45.155–46.070 |
| 11 | 2 | 31 | 39.205–39.254 |
| 6 | 3 | 30 | 45.148–46.024 |

Each has three physical repetitions. The KS1–3 matrix also includes adjacent AR
controls, totaling **27 additional physical transients**. OPM retains gradual
attacks. All four production configurations take the instant internal path.
For KS2/3, subsequent unwanted decay invalidates a plateau-based jt51 duration;
the initial jump is established separately by waveform energy and internal
trace, not by forcing the analyzer to return a duration.

Detailed phase/history and source-map evidence is in
`artifacts/ar14-investigation/findings.md`, with immutable inputs, output hashes,
event clocks and selected pipeline transitions. Production files were not edited.

## Confirmed raw-zero rate/key-scale boundary

Two isolated profiles distinguish the decay stages, using AR31 and the same
qualified carrier:

- **hold-d1:** D1R=0, D1L=15, D2R=0. The high decay target keeps the observed hold
  in the first decay stage.
- **hold-d2:** D1R=31, D1L=4, D2R=0. The first decay rapidly reaches the lower
  level, then the second decay should hold.

Each profile was measured at all four KS settings, three independent
initializations each: **24 physical recordings**. The PCB holds the intended
levels, and OPM agrees. Production jt51 loses level at nonzero KS:

| KS | PCB hold-d1 level, approximately | jt51 tail | PCB hold-d2 level, approximately | jt51 tail |
|---|---:|---:|---:|---:|
| 0 | 8169.6 | 8169.5 | 2042.3 | 2042.3 |
| 1 | 8169.5 | 7995.3 | 2042.3 | 1998.7 |
| 2 | 8169.6 | 7821.0 | 2042.3 | 1955.2 |
| 3 | 8169.5 | 5907.3 | 2042.3 | 1476.7 |

Tail levels are the final-quarter projected medians. KS1's output can look flat
within that short quarter while already being about 2.13% too low; its absolute
level therefore matters. KS2/3 also fail the relative-flatness gate. Physical
repeat variation is far below these differences. The wrong level is not scored
as an altered attack duration.

Four **AR=0** negative controls, each repeated three times, produce exactly zero
PCM on both physical channels and in OPM throughout the window. Production
jt51 leaks about ±4 at KS2 and reaches about ±2208 at KS3. An otherwise matching
AR1/KS3 control produces both positive and negative audio in all three physical
runs (about ±4k), so silence is not being used as a standalone sound-path proof.
The AR0/KS0 and KS1 software outputs also remain digitally silent in this finite
window; that does not prove an infinite hold at those settings.

Read-only traces for thirteen selected cases match their uninstrumented samples
byte for byte. They show raw configured rate zero becoming effective rates
2/4/9/18 after key scaling at keycode 18. Nonzero KS then advances AR, D1R and
D2R state. At AR0/KS1 the internal change is not yet observable after Yamaha
quantization; the directly observed AR0 gaps are KS2/3.

Yamaha application notes describe rate/key-scale calculation and effective
rates 0–3 as infinite, but the reviewed pages do not explicitly state the raw-zero
override before scaling. Physical observations establish that boundary here.
Independent Nuked-OPM and MAME ymfm both preserve raw-zero inhibition. The common
rate-construction path explains why these behaviors belong in a combined gap
inventory rather than separate speculative fixes. See
`artifacts/eg-zero-rate-investigation/findings.md` for primary-page references,
independent review and selected stage-aligned traces.

## Reproduction

From this task directory, use Python with the already qualified PyUSB environment:

```
python scripts/monitor.py emit tone --output artifacts/fresh-tone.bin
go run host/envelope_programs.go -base artifacts/fresh-tone.bin -output artifacts/fresh-ar
python scripts/capture-event.py artifacts/fresh-ar/ar14-init.bin artifacts/fresh-ar/keyon.bin artifacts/fresh-ar14 --capture-id 2000
go run host/envelope.go host/tone.go -increment 65984 -window 32 -csv artifacts/fresh-ar14-amplitude.csv artifacts/fresh-ar14-0-0.csv
```

Generate a key-scale boundary with `-ks 1 -first 12 -last 14`, or isolated hold
fixtures with `-ks 3 -profile hold-d1` / `hold-d2`. Use `-first 0 -last 0` for the
AR0 control. Each destination must be new. Model commands, from the repo root
with `setprj.sh` sourced, are:

```
bash tasks/jtcores-143/ver/jt51/sim.sh --event INIT.bin EVENT.bin FRESH-jt51.csv
bash tasks/jtcores-143/ver/opm/sim.sh --event INIT.bin EVENT.bin FRESH-opm.csv
```

Use `-column left` for model CSV analysis. For hold profiles pass `-curve-only`;
their attack duration is not the scored observable. Test the analysis with:

```
go test host/envelope.go host/tone.go host/envelope_test.go
go test host/phase.go host/tone.go host/phase_test.go host/tone_test.go
```

## Evidence and remaining scope

There are **135 transport-qualified physical event captures**: nine initial
qualification recordings, 60 main attacks, 27 KS boundary attacks, 24 isolated
holds, twelve AR0 silent controls and three AR1 positive controls. Silence is
explicitly separated from the 123 nonzero recordings. All transfers and framing
checks pass; no CPU reset or dropped reply byte occurred during the campaign.

Artifacts are retained under `transient-qualification`, `transient-wrapper-check`,
`envelope-native`, `envelope-ks`, `eg-hold`, `eg-zero-attack`,
`ar14-investigation` and `eg-zero-rate-investigation`. They remain outside git.
Every campaign manifest points to the complete source programs and hashes.

Still required: longer acquisition for slow rates/LFO, remaining AR/KS/KC
combinations, D1R/D2R and D1L sweeps, release/hold/retrigger/live-register behavior,
and the remaining LFO/noise/algorithm/feedback/CSM/accumulation audit. The current
recorder buffer cannot establish complete slow envelopes from a 293 ms window.
No full envelope, chip or issue completion is claimed.
